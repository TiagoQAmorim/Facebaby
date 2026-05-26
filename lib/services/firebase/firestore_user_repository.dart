import 'dart:async' show unawaited;

import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'cloud_load_status.dart';
import 'firestore_service.dart';

class FirestoreUserRepository {
  FirestoreUserRepository._();

  static final FirestoreUserRepository instance = FirestoreUserRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> userDoc(String uid) => _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> babiesCol(String uid) => userDoc(uid).collection('babies');

  CollectionReference<Map<String, dynamic>> eventsCol(String uid) => userDoc(uid).collection('events');

  CollectionReference<Map<String, dynamic>> memoryDeletionsCol(String uid) =>
      userDoc(uid).collection('memory_deletions');

  /// ID estável para `users/{uid}/memory_deletions/{id}`.
  static String memoryDeletionDocId(String babyCloudId, String badgeId) {
    final b = babyCloudId.trim();
    final g = badgeId.trim();
    final raw = '${b}__${g}'.replaceAll('/', '_');
    if (raw.length <= 1200) return raw;
    return raw.substring(0, 1200);
  }

  void _log(String op, String uid, String path, [Object? extra]) {
    final msg = 'Firestore op=$op uid=$uid path=$path';
    if (extra != null) {
      debugPrint('$msg extra=$extra');
    } else {
      debugPrint(msg);
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    _log('get', uid, 'users/$uid');
    final snap = await userDoc(uid).get();
    if (!snap.exists) return null;
    return snap.data();
  }

  Future<void> saveUserProfile(String uid, Map<String, dynamic> profile) async {
    _log('set(merge)', uid, 'users/$uid', profile.keys.toList(growable: false));
    await userDoc(uid).set(
      {
        ...profile,
        'updatedAt': FieldValue.serverTimestamp(),
        if ((profile['createdAt'] ?? '').toString().isEmpty) 'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<Map<String, dynamic>?> getBaby(String uid, String babyId) async {
    _log('get', uid, 'users/$uid/babies/$babyId');
    final snap = await babiesCol(uid).doc(babyId).get();
    if (!snap.exists) return null;
    return {'id': snap.id, ...?snap.data()};
  }

  Future<String> saveBaby(String uid, Map<String, dynamic> baby) async {
    final id = (baby['id'] as String?)?.trim();
    final ref = (id == null || id.isEmpty) ? babiesCol(uid).doc() : babiesCol(uid).doc(id);
    _log('set(merge)', uid, 'users/$uid/babies/${ref.id}', baby.keys.toList(growable: false));
    await ref.set(
      {
        ...baby..remove('id'),
        'updatedAt': FieldValue.serverTimestamp(),
        if (baby['createdAt'] == null) 'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return ref.id;
  }

  /// Regista na nuvem que um selo foi apagado (sobrevive a logout/login noutro dispositivo).
  Future<void> setMemoryBadgeDeletion({
    required String babyCloudId,
    required String badgeId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final bCloud = babyCloudId.trim();
    final bid = badgeId.trim();
    if (bCloud.isEmpty || bid.isEmpty) return;
    final docId = memoryDeletionDocId(bCloud, bid);
    _log('set', uid, 'users/$uid/memory_deletions/$docId');
    await memoryDeletionsCol(uid).doc(docId).set({
      'baby_id': bCloud,
      'badge_id': bid,
      'deleted_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clearMemoryBadgeDeletion({
    required String babyCloudId,
    required String badgeId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final bCloud = babyCloudId.trim();
    final bid = badgeId.trim();
    if (bCloud.isEmpty || bid.isEmpty) return;
    final docId = memoryDeletionDocId(bCloud, bid);
    _log('delete', uid, 'users/$uid/memory_deletions/$docId');
    await memoryDeletionsCol(uid).doc(docId).delete();
  }

  Future<List<String>> listDeletedBadgeIdsForBaby(String babyCloudId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];
    final bCloud = babyCloudId.trim();
    if (bCloud.isEmpty) return const [];
    _log('query', uid, 'users/$uid/memory_deletions', {'baby_id': bCloud});
    final snap =
        await memoryDeletionsCol(uid).where('baby_id', isEqualTo: bCloud).get();
    final out = <String>[];
    for (final d in snap.docs) {
      final bid = (d.data()['badge_id'] as String?)?.trim() ?? '';
      if (bid.isNotEmpty) out.add(bid);
    }
    return out;
  }

  Future<void> setSelectedBabyId(String uid, String babyId) async {
    _log('set(merge)', uid, 'users/$uid', {'selectedBabyId': babyId});
    await userDoc(uid).set(
      {
        'selectedBabyId': babyId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<Map<String, dynamic>?> getSelectedBaby(String uid) async {
    final profile = await getUserProfile(uid);
    final selectedId = (profile?['selectedBabyId'] as String?)?.trim();
    if (selectedId == null || selectedId.isEmpty) return null;
    return await getBaby(uid, selectedId);
  }

  Future<String?> _pickAnyBabyId(String uid) async {
    _log('query', uid, 'users/$uid/babies', 'pickAny');
    final snap = await babiesCol(uid).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Future<void> saveEvent(String uid, Map<String, dynamic> event) async {
    final ref = eventsCol(uid).doc();
    _log('create', uid, 'users/$uid/events/${ref.id}', event['type']);
    await ref.set(
      {
        ...event,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  CloudLoadResult _mapError(Object e) {
    if (e is FirebaseException) {
      final code = e.code;
      if (code == 'permission-denied') {
        return CloudLoadResult(status: CloudLoadStatus.permissionDenied, error: e, errorCode: code);
      }
      if (code == 'unavailable' || code == 'deadline-exceeded' || code == 'network-request-failed') {
        return CloudLoadResult(status: CloudLoadStatus.networkError, error: e, errorCode: code);
      }
      return CloudLoadResult(status: CloudLoadStatus.unknownError, error: e, errorCode: code);
    }
    return CloudLoadResult(status: CloudLoadStatus.unknownError, error: e);
  }

  Future<T> _retryOnUnavailable<T>(
    String uid,
    String op,
    Future<T> Function() fn, {
    int maxAttempts = 3,
    Duration baseDelay = const Duration(milliseconds: 450),
  }) async {
    Object? lastErr;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _log('$op:attempt', uid, 'users/$uid', attempt);
        return await fn();
      } catch (e) {
        lastErr = e;
        if (e is FirebaseException) {
          final code = e.code;
          final retryable = code == 'unavailable' || code == 'deadline-exceeded' || code == 'network-request-failed';
          if (retryable && attempt < maxAttempts) {
            final ms = baseDelay.inMilliseconds * (1 << (attempt - 1));
            await Future<void>.delayed(Duration(milliseconds: ms));
            continue;
          }
        }
        rethrow;
      }
    }
    throw lastErr ?? StateError('Unknown retry failure');
  }

  /// Carrega perfil e bebê selecionado.
  /// - Se não existir doc /users/{uid}, tenta migrar do schema legado e re-tenta.
  Future<CloudLoadResult> loadGate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const CloudLoadResult(status: CloudLoadStatus.unauthenticated);
    final uid = user.uid;
    debugPrint('CloudGate uid=$uid');

    try {
      var profile = await _retryOnUnavailable(uid, 'loadGate.profile', () => getUserProfile(uid));
      if (profile == null) {
        // Tenta migração do schema legado (mothers/babies em subcoleções) se houver algo.
        final migrated = await _retryOnUnavailable(uid, 'loadGate.migrateLegacy', () => _migrateLegacyIfAny(uid: uid));
        if (migrated) {
          profile = await _retryOnUnavailable(uid, 'loadGate.profile', () => getUserProfile(uid));
        }
      }

      if (profile == null) {
        return CloudLoadResult(status: CloudLoadStatus.newUser, uid: uid);
      }

      final status = (profile['status'] as String?)?.trim().toLowerCase();
      if (status == 'suspended') {
        return CloudLoadResult(status: CloudLoadStatus.suspended, uid: uid);
      }

      unawaited(_touchLastLogin(uid));

      final selectedId = (profile['selectedBabyId'] as String?)?.trim();
      if (selectedId == null || selectedId.isEmpty) {
        // If profile exists but selectedBabyId is missing, try to recover from cloud babies collection
        // instead of forcing the user to re-register.
        final any = await _retryOnUnavailable(uid, 'loadGate.pickAnyBaby', () => _pickAnyBabyId(uid));
        if (any != null && any.isNotEmpty) {
          await _retryOnUnavailable(uid, 'loadGate.setSelectedBaby', () => setSelectedBabyId(uid, any));
          return CloudLoadResult(status: CloudLoadStatus.loaded, uid: uid, selectedBabyId: any);
        }
        return CloudLoadResult(status: CloudLoadStatus.missingBaby, uid: uid);
      }

      final baby = await _retryOnUnavailable(uid, 'loadGate.baby', () => getBaby(uid, selectedId));
      if (baby == null) {
        return CloudLoadResult(status: CloudLoadStatus.missingBaby, uid: uid, selectedBabyId: selectedId);
      }

      return CloudLoadResult(status: CloudLoadStatus.loaded, uid: uid, selectedBabyId: selectedId);
    } catch (e, st) {
      debugPrint('CloudGate load failed: $e\n$st');
      final mapped = _mapError(e);
      return CloudLoadResult(
        status: mapped.status,
        uid: uid,
        error: mapped.error,
        errorCode: mapped.errorCode,
      );
    }
  }

  /// Migra dados do schema legado atual (mothers/babies em subcoleções) para:
  /// users/{uid} + users/{uid}/babies/{babyId}
  Future<bool> _migrateLegacyIfAny({required String uid}) async {
    try {
      final legacy = FirestoreService.instance;
      final babies = await legacy.listBabies();
      if (babies.isEmpty) return false;
      final name = FirebaseAuth.instance.currentUser?.displayName?.trim();
      final profile = await legacy.getProfile();

      // Escolhe primeiro bebê como selecionado.
      final firstBaby = babies.isEmpty ? null : babies.first;

      await saveUserProfile(uid, {
        if (name != null && name.isNotEmpty) 'name': name,
        'email': FirebaseAuth.instance.currentUser?.email,
        'phone': profile?['phone'],
        'birth_date': profile?['birth_date'] ?? profile?['birthDate'],
        'height_cm': profile?['height_cm'] ?? profile?['heightCm'],
        'father_height_cm': profile?['father_height_cm'] ?? profile?['fatherHeightCm'],
        'photo_url': profile?['photo_url'] ?? profile?['photoUrl'],
        'father_photo_url':
            profile?['father_photo_url'] ?? profile?['fatherPhotoUrl'],
      });

      String? selected;
      for (final b in babies) {
        final legacyId = (b['id'] as String?)?.trim();
        final newId = await saveBaby(uid, {
          'id': legacyId, // preserva id se existir
          'name': b['name'],
          'sex': b['sex'],
          'birthDate': b['birth_date'],
          'weightKg': b['weight_kg'],
          'heightCm': b['height_cm'],
          'photoUrl': b['photo_url'],
        });
        selected ??= newId;
      }

      // Se não tinha babies (só mãe), ainda assim criamos perfil.
      final chosen = selected ?? ((firstBaby?['id'] as String?)?.trim());
      if (chosen != null && chosen.isNotEmpty) {
        await setSelectedBabyId(uid, chosen);
      }
      return true;
    } catch (e) {
      debugPrint('Legacy migration skipped: $e');
      return false;
    }
  }

  Future<void> _touchLastLogin(String uid) async {
    try {
      final locale = PlatformDispatcher.instance.locale;
      final country = locale.countryCode?.trim().toUpperCase();
      await userDoc(uid).set({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (country != null && country.length == 2) 'countryCode': country,
        'localeCountry': locale.toLanguageTag(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('lastLoginAt update skipped: $e');
    }
  }
}

