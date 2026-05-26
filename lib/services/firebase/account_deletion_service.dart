import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../auth_local_scope.dart';
import '../app_database.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'firestore_user_repository.dart';
import 'storage_service.dart';
import 'weekly_photo_public_sync.dart';

/// Fluxo terminou apenas porque o Firebase exige credencial mais recente; o utilizador deve reautenticar **sem** novo login manual.
class AccountDeletionRequiresRecentLogin implements Exception {
  AccountDeletionRequiresRecentLogin();
}

class AccountDeletionService {
  AccountDeletionService._();

  static final AccountDeletionService instance = AccountDeletionService._();

  /// Elimina dados na nuvem e em seguida o utilizador Firebase Auth + cache local.
  ///
  /// Se `user.delete()` falhar por [requires-recent-login], o cache local é limpo na mesma
  /// (dados cloud já foram apagados) — evita erros ao criar conta nova com o mesmo e-mail.
  Future<void> deleteAllUserDataAndAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Usuário não autenticado');
    final uid = user.uid;

    await _deleteCloudData(uid);

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        await _wipeLocalOnly();
        throw AccountDeletionRequiresRecentLogin();
      }
      rethrow;
    }

    await _signOutAndWipeLocal();
  }

  /// Apenas após reautenticar bem-sucedida, quando os dados cloud já foram apagados.
  Future<void> deleteFirebaseAuthAndLocalOnly() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Usuário não autenticado');
    try {
      await user.reload();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AccountDeletionRequiresRecentLogin();
      }
      rethrow;
    }
    await _signOutAndWipeLocal();
  }

  Future<void> _signOutAndWipeLocal() async {
    await AuthLocalScope.clearBinding();
    await AuthService.instance.signOut(trustAuthNullImmediately: true);
    await _wipeLocalOnly();
  }

  Future<void> _wipeLocalOnly() async {
    try {
      await AppDatabase.instance.wipeLocalCache();
    } catch (_) {}
  }

  Future<void> _deleteCloudData(String uid) async {
    final fs = FirestoreService.instance;
    final repo = FirestoreUserRepository.instance;
    final db = FirebaseFirestore.instance;

    final babies = await fs.listBabies();
    for (final b in babies) {
      final id = (b['id'] as String?)?.trim();
      if (id == null || id.isEmpty) continue;
      await _deleteBabyTree(uid, id, fs);
    }

    await _deleteAllInCollection(fs.eventsCol());
    await _deleteAllInCollection(fs.babiesCol());
    await _deleteAllInCollection(repo.memoryDeletionsCol(uid));

    await _deletePublicMemoriesForUser(uid, db);
    await _clearWeeklySpotlightIfUser(uid, db);
    await _deleteWeeklyPhotoReportsForUser(uid, db);

    try {
      await StorageService.instance.deleteFolder('users/$uid');
    } catch (e) {
      debugPrint('AccountDeletion: storage users/$uid failed: $e');
    }

    try {
      await fs.userDoc().delete();
    } catch (e) {
      debugPrint('AccountDeletion: user doc delete failed: $e');
    }

    // Nunca apagar admins / admins_by_email — painel admin é independente do app.
  }

  Future<void> _deleteBabyTree(
    String uid,
    String babyId,
    FirestoreService fs,
  ) async {
    await _deleteEventsForBaby(fs, babyId);

    try {
      await FirestoreUserRepository.instance.babiesCol(uid).doc(babyId).delete();
    } catch (_) {}

    try {
      await fs.deleteBaby(babyId);
    } catch (_) {}

    try {
      await StorageService.instance.deleteFolder('users/$uid/babies/$babyId');
    } catch (_) {}

    await _deletePublicMemoriesForBaby(uid, babyId, FirebaseFirestore.instance);
  }

  Future<void> _deletePublicMemoriesForBaby(
    String uid,
    String babyCloudId,
    FirebaseFirestore db,
  ) async {
    final baby = babyCloudId.trim();
    if (baby.isEmpty) return;
    final col = db.collection('public_memories');
    final prefix = '${uid}_${baby}_';
    try {
      while (true) {
        final snap = await col
            .orderBy(FieldPath.documentId)
            .startAt([prefix])
            .endAt(['$prefix\uf8ff'])
            .limit(100)
            .get();
        if (snap.docs.isEmpty) break;
        for (final doc in snap.docs) {
          await _deletePublicMemoryDocTree(doc.reference);
        }
        if (snap.docs.length < 100) break;
      }
    } catch (e, st) {
      debugPrint(
        'AccountDeletion: public_memories baby=$baby failed: $e\n$st',
      );
    }
  }

  /// Apaga por id canónico a partir do catálogo local (antes de limpar SQLite).
  Future<void> _deletePublicMemoriesFromLocalCatalog(
    String uid,
    FirebaseFirestore db,
  ) async {
    try {
      final babies = await AppDatabase.instance.listBabies();
      for (final baby in babies) {
        final localId = baby['id'];
        if (localId is! int) continue;
        final cloud = (baby['cloud_id'] as String?)?.trim() ?? '';
        if (cloud.isEmpty) continue;
        final rows =
            await AppDatabase.instance.listBabyMemories(babyId: localId);
        for (final row in rows) {
          if (((row['is_public'] as int?) ?? 0) != 1) continue;
          final badgeId = ((row['badge_id'] as String?) ?? '').trim();
          if (badgeId.isEmpty) continue;
          final docId = WeeklyPhotoPublicSync.publicDocId(
            ownerUid: uid,
            babyCloudId: cloud,
            badgeId: badgeId,
          );
          await _deletePublicMemoryDocTree(
            db.collection('public_memories').doc(docId),
          );
        }
      }
    } catch (e, st) {
      debugPrint(
        'AccountDeletion: _deletePublicMemoriesFromLocalCatalog failed: $e\n$st',
      );
    }
  }

  Future<void> _deletePublicMemoriesForUser(
    String uid,
    FirebaseFirestore db,
  ) async {
    try {
      await _deletePublicMemoriesFromLocalCatalog(uid, db);

      final col = db.collection('public_memories');
      final seen = <String>{};

      Future<void> purgeDoc(DocumentReference<Map<String, dynamic>> ref) async {
        if (!seen.add(ref.id)) return;
        await _deletePublicMemoryDocTree(ref);
      }

      Future<void> purgeQuery(Query<Map<String, dynamic>> query) async {
        while (true) {
          QuerySnapshot<Map<String, dynamic>> snap;
          try {
            snap = await query.limit(100).get();
          } catch (e, st) {
            debugPrint('AccountDeletion: public_memories query failed: $e\n$st');
            break;
          }
          if (snap.docs.isEmpty) break;
          for (final doc in snap.docs) {
            await purgeDoc(doc.reference);
          }
          if (snap.docs.length < 100) break;
        }
      }

      // Campos gravados pelo app (`userId`, `owner_uid`).
      await purgeQuery(col.where('userId', isEqualTo: uid));
      await purgeQuery(col.where('owner_uid', isEqualTo: uid));

      // Id canónico: `{uid}_{babyCloudId}_{badgeId}` — apanha docs mesmo sem campo userId.
      final idPrefix = '${uid}_';
      await purgeQuery(
        col
            .orderBy(FieldPath.documentId)
            .startAt([idPrefix])
            .endAt(['$idPrefix\uf8ff']),
      );
    } catch (e, st) {
      debugPrint('AccountDeletion: _deletePublicMemoriesForUser failed: $e\n$st');
    }
  }

  Future<void> _deletePublicMemoryDocTree(
    DocumentReference<Map<String, dynamic>> memRef,
  ) async {
    try {
      while (true) {
        final likes = await memRef.collection('likes').limit(200).get();
        if (likes.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final d in likes.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
      await memRef.delete();
    } catch (e) {
      debugPrint('AccountDeletion: public memory ${memRef.id} failed: $e');
    }
  }

  Future<void> _clearWeeklySpotlightIfUser(
    String uid,
    FirebaseFirestore db,
  ) async {
    try {
      final spotRef =
          db.collection('weekly_photo_contests').doc('spotlight_current');
      final snap = await spotRef.get();
      if (!snap.exists) return;
      final d = snap.data();
      if (d == null) return;
      final winnerUid = '${d['winner_user_id'] ?? d['winnerUserId'] ?? ''}'.trim();
      final memId =
          '${d['winner_public_memory_id'] ?? d['winnerPublicMemoryId'] ?? ''}'.trim();
      if (winnerUid == uid ||
          (memId.isNotEmpty && memId.startsWith('${uid}_'))) {
        await spotRef.delete();
      }
    } catch (e) {
      debugPrint('AccountDeletion: spotlight clear failed: $e');
    }
  }

  Future<void> _deleteWeeklyPhotoReportsForUser(
    String uid,
    FirebaseFirestore db,
  ) async {
    final col = db.collection('weekly_photo_reports');
    try {
      for (final field in ['reporterUid', 'reporter_uid', 'targetUserId']) {
        while (true) {
          final snap = await col.where(field, isEqualTo: uid).limit(100).get();
          if (snap.docs.isEmpty) break;
          final batch = db.batch();
          for (final d in snap.docs) {
            batch.delete(d.reference);
          }
          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint('AccountDeletion: weekly_photo_reports failed: $e');
    }
  }

  Future<void> _deleteAllInCollection(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    while (true) {
      final snap = await col.limit(250).get();
      if (snap.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteEventsForBaby(FirestoreService fs, String babyId) async {
    while (true) {
      final snap = await fs
          .eventsCol()
          .where('baby_id', isEqualTo: babyId)
          .limit(250)
          .get();
      if (snap.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }
}
