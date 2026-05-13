import 'dart:async' show Completer, unawaited;
import 'dart:convert' show base64Decode;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_database.dart';
import '../premium/premium_service.dart';
import 'firestore_service.dart';
import 'profile_cloud_sync.dart';
import 'storage_service.dart';
import 'weekly_photo_public_sync.dart';

class MemoryCloudSync {
  MemoryCloudSync._();

  static bool get _authed => FirebaseAuth.instance.currentUser != null;

  /// Evita dois envios em paralelo para o mesmo badge (leitura / merge em ordem errada).
  static final Map<String, Future<void>> _pushInFlight = {};

  static void pushBadgeMemorySoon({required int localBabyId, required String badgeId}) {
    if (!_authed || kIsWeb) return;
    unawaited(
      pushBadgeMemory(localBabyId: localBabyId, badgeId: badgeId).catchError((e, st) {
        debugPrint('MemoryCloudSync.pushBadgeMemorySoon failed: $e\n$st');
      }),
    );
  }

  static Future<void> pushBadgeMemory({required int localBabyId, required String badgeId}) async {
    if (!_authed || kIsWeb) {
      return;
    }
    final premium = PremiumService.instance.isPremium;
    if (!premium) {
      // Sem Premium não enviamos a memória privada para a subcoleção do bebê, mas o mural /
      // `public_memories` (Foto da Semana) precisa existir quando a mãe marca como pública.
      await WeeklyPhotoPublicSync.syncBadgeMemory(localBabyId: localBabyId, badgeId: badgeId);
      return;
    }
    final gateKey = '$localBabyId::$badgeId';
    final previous = _pushInFlight[gateKey];
    if (previous != null) {
      try {
        await previous;
      } catch (_) {}
    }
    final done = Completer<void>();
    _pushInFlight[gateKey] = done.future;
    try {
      await _pushBadgeMemoryBody(localBabyId: localBabyId, badgeId: badgeId);
    } finally {
      done.complete();
      if (identical(_pushInFlight[gateKey], done.future)) {
        _pushInFlight.remove(gateKey);
      }
    }
  }

  static Future<void> _pushBadgeMemoryBody({required int localBabyId, required String badgeId}) async {
    try {
      await ProfileCloudSync.pushBaby(localBabyId);
      final baby = await AppDatabase.instance.getBabyById(localBabyId);
      final babyCloud = (baby?['cloud_id'] as String?)?.trim();
      if (babyCloud == null || babyCloud.isEmpty) return;

      final rows = await AppDatabase.instance.listBabyMemories(babyId: localBabyId);
      final row = rows.cast<Map<String, Object?>>().firstWhere(
            (r) => ((r['badge_id'] as String?) ?? '').trim() == badgeId,
            orElse: () => const {},
          );
      if (row.isEmpty) return;

      DateTime? parseOptIso(Object? v) {
        final s = (v as String?)?.trim();
        if (s == null || s.isEmpty) return null;
        return DateTime.tryParse(s);
      }

      // Large base64 photos can exceed Firestore document size. We upload to Storage and
      // store only the URL in Firestore to guarantee persistence across reinstalls.
      String? photoUrl;
      final pb = (row['photo_b64'] as String?)?.trim();
      if (pb != null && pb.isNotEmpty) {
        try {
          final bytes = Uint8List.fromList(base64Decode(pb));
          photoUrl = await StorageService.instance.uploadMemoryPhotoBytes(
            babyId: babyCloud,
            badgeId: badgeId,
            bytes: bytes,
            fileExt: 'jpg',
            versionToken: DateTime.now().millisecondsSinceEpoch.toString(),
          );
          // Persist URL locally too (so UI can render after reinstall/hydration).
          await AppDatabase.instance.upsertBabyMemory(
            babyId: localBabyId,
            badgeId: badgeId,
            title: (row['title'] as String?) ?? '—',
            description: (row['description'] as String?)?.toString(),
            photoB64: null,
            photoUrl: photoUrl,
            memoryDate: DateTime.tryParse((row['memory_date'] as String?) ?? '') ?? DateTime.now(),
            babyAgeAtMoment: (row['baby_age_at_moment'] as String?)?.toString(),
            weightAtMoment: (row['weight_at_moment'] as num?)?.toDouble(),
            heightAtMoment: (row['height_at_moment'] as num?)?.toDouble(),
            moodAtMoment: (row['mood_at_moment'] as String?)?.toString(),
            motherNotes: (row['mother_notes'] as String?)?.toString(),
            isFavorite: ((row['is_favorite'] as int?) ?? 0) == 1,
            isPublic: ((row['is_public'] as int?) ?? 0) == 1,
            publicEnabledAt: parseOptIso(row['public_enabled_at']),
            publicDisabledAt: parseOptIso(row['public_disabled_at']),
            eligibleForWeeklyPhoto: ((row['eligible_weekly_photo'] as int?) ?? 0) == 1,
            weeklyPhotoWinner: ((row['weekly_photo_winner'] as int?) ?? 0) == 1,
            weeklyPhotoWeekId: (row['weekly_photo_week_id'] as String?)?.trim(),
            showBabyFirstNameWhenPublic: ((row['show_baby_name_public'] as int?) ?? 1) == 1,
          );
        } catch (e) {
          debugPrint('MemoryCloudSync.uploadMemoryPhoto failed: $e');
          rethrow;
        }
      }

      final merge = <String, dynamic>{
        'badge_id': badgeId,
        'title': row['title'],
        'description': row['description'],
        'memory_date': row['memory_date'],
        'baby_age_at_moment': row['baby_age_at_moment'],
        'weight_at_moment': row['weight_at_moment'],
        'height_at_moment': row['height_at_moment'],
        'mood_at_moment': row['mood_at_moment'],
        'mother_notes': row['mother_notes'],
        'is_favorite': ((row['is_favorite'] as int?) ?? 0) == 1,
        'is_public': ((row['is_public'] as int?) ?? 0) == 1,
        'public_enabled_at': row['public_enabled_at'],
        'public_disabled_at': row['public_disabled_at'],
        'eligible_weekly_photo': ((row['eligible_weekly_photo'] as int?) ?? 0) == 1,
        'show_baby_name_public': ((row['show_baby_name_public'] as int?) ?? 1) == 1,
      };
      final uploadedUrl = photoUrl?.trim();
      final existingLocalUrl = (row['photo_path'] as String?)?.trim();
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        merge['photo_url'] = uploadedUrl;
        merge['photo_b64'] = FieldValue.delete();
      } else if (existingLocalUrl != null && existingLocalUrl.isNotEmpty) {
        // Só URL na BD (pós-upload): mantém referência na nuvem ao editar texto sem novo ficheiro.
        merge['photo_url'] = existingLocalUrl;
        merge['photo_b64'] = FieldValue.delete();
      }

      await FirestoreService.instance.upsertMemoryByBadge(
        babyId: babyCloud,
        badgeId: badgeId,
        data: merge,
      );

      await WeeklyPhotoPublicSync.syncBadgeMemory(localBabyId: localBabyId, badgeId: badgeId);
    } catch (e, st) {
      debugPrint('MemoryCloudSync.pushBadgeMemory failed: $e\n$st');
      rethrow;
    }
  }
}

