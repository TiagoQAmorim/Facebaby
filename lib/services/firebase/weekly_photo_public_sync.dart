import 'dart:async' show unawaited;
import 'dart:convert' show base64Decode;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_database.dart';
import '../../utils/weekly_photo_schedule.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

/// Escreve apenas campos seguros em `public_memories/{docId}` (sem dados médicos da mãe).
class WeeklyPhotoPublicSync {
  WeeklyPhotoPublicSync._();

  static bool get _authed => FirebaseAuth.instance.currentUser != null;

  static DateTime? _parseOptIso(Object? v) {
    final s = (v as String?)?.trim();
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static String _firstName(String? fullName) {
    final t = fullName?.trim() ?? '';
    if (t.isEmpty) return '';
    return t.split(RegExp(r'\s+')).firstWhere((s) => s.isNotEmpty, orElse: () => '');
  }

  /// `docId` determinístico — não expõe ids internos sensíveis num único campo.
  static String publicDocId({
    required String ownerUid,
    required String babyCloudId,
    required String badgeId,
  }) =>
      '${ownerUid}_${babyCloudId}_$badgeId';

  /// Garante URL HTTPS (upload para Storage se a foto estiver só em `photo_b64` ou URL não-HTTPS).
  static Future<String?> _ensureHttpsPhotoUrl({
    required int localBabyId,
    required String babyCloud,
    required String badgeId,
    required Map<String, Object?> row,
    required String initialPhotoUrl,
    required String photoB64,
  }) async {
    var url = initialPhotoUrl.trim();
    if (url.toLowerCase().startsWith('https://')) return url;

    final pb = photoB64.trim();
    if (pb.isEmpty) {
      return null;
    }

    try {
      final bytes = Uint8List.fromList(base64Decode(pb));
      url = await StorageService.instance.uploadMemoryPhotoBytes(
        babyId: babyCloud,
        badgeId: badgeId,
        bytes: bytes,
        fileExt: 'jpg',
        versionToken: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      await AppDatabase.instance.upsertBabyMemory(
        babyId: localBabyId,
        badgeId: badgeId,
        title: (row['title'] as String?) ?? '—',
        description: (row['description'] as String?)?.toString(),
        photoB64: null,
        photoUrl: url,
        memoryDate: DateTime.tryParse((row['memory_date'] as String?) ?? '') ?? DateTime.now(),
        babyAgeAtMoment: (row['baby_age_at_moment'] as String?)?.toString(),
        weightAtMoment: (row['weight_at_moment'] as num?)?.toDouble(),
        heightAtMoment: (row['height_at_moment'] as num?)?.toDouble(),
        moodAtMoment: (row['mood_at_moment'] as String?)?.toString(),
        motherNotes: (row['mother_notes'] as String?)?.toString(),
        isFavorite: ((row['is_favorite'] as int?) ?? 0) == 1,
        isPublic: ((row['is_public'] as int?) ?? 0) == 1,
        publicEnabledAt: _parseOptIso(row['public_enabled_at']),
        publicDisabledAt: _parseOptIso(row['public_disabled_at']),
        eligibleForWeeklyPhoto: ((row['eligible_weekly_photo'] as int?) ?? 0) == 1,
        weeklyPhotoWinner: ((row['weekly_photo_winner'] as int?) ?? 0) == 1,
        weeklyPhotoWeekId: (row['weekly_photo_week_id'] as String?)?.trim(),
        showBabyFirstNameWhenPublic: ((row['show_baby_name_public'] as int?) ?? 1) == 1,
      );
      return url.trim();
    } catch (e, st) {
      debugPrint('WeeklyPhotoPublicSync: upload memory photo failed: $e\n$st');
      return null;
    }
  }

  static Future<void> syncBadgeMemory({
    required int localBabyId,
    required String badgeId,
  }) async {
    if (!_authed || kIsWeb) return;

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final baby = await AppDatabase.instance.getBabyById(localBabyId);
      final babyCloud = (baby?['cloud_id'] as String?)?.trim();
      if (babyCloud == null || babyCloud.isEmpty) return;

      final rows = await AppDatabase.instance.listBabyMemories(babyId: localBabyId);
      final row = rows.cast<Map<String, Object?>>().firstWhere(
            (r) => ((r['badge_id'] as String?) ?? '').trim() == badgeId,
            orElse: () => const {},
          );
      if (row.isEmpty) return;

      final isPublic = ((row['is_public'] as int?) ?? 0) == 1;
      var photoUrl = ((row['photo_path'] as String?) ?? '').trim();
      final photoB64 = ((row['photo_b64'] as String?) ?? '').trim();
      final hasPhoto = photoUrl.isNotEmpty || photoB64.isNotEmpty;

      final docId = publicDocId(ownerUid: uid, babyCloudId: babyCloud, badgeId: badgeId);

      if (!isPublic || !hasPhoto) {
        await FirestoreService.instance.deletePublicMemoryDoc(docId);
        return;
      }

      final effectiveUrl = await _ensureHttpsPhotoUrl(
        localBabyId: localBabyId,
        babyCloud: babyCloud,
        badgeId: badgeId,
        row: row,
        initialPhotoUrl: photoUrl,
        photoB64: photoB64,
      );
      if (effectiveUrl == null || effectiveUrl.isEmpty) {
        await FirestoreService.instance.deletePublicMemoryDoc(docId);
        return;
      }
      if (!effectiveUrl.toLowerCase().startsWith('https://')) {
        await FirestoreService.instance.deletePublicMemoryDoc(docId);
        return;
      }
      photoUrl = effectiveUrl;

      final title = (row['title'] as String?)?.trim() ?? '—';
      final description = (row['description'] as String?)?.trim();
      final memoryDateStr = (row['memory_date'] as String?)?.trim();
      final memoryDate = DateTime.tryParse(memoryDateStr ?? '');
      final babyAgeAtMoment = (row['baby_age_at_moment'] as String?)?.trim();
      final showBabyName = ((row['show_baby_name_public'] as int?) ?? 1) == 1;
      final peRaw = (row['public_enabled_at'] as String?)?.trim();
      final publicEnabledAt = peRaw != null && peRaw.isNotEmpty ? DateTime.tryParse(peRaw) : null;
      final poolAnchor = memoryDate ?? publicEnabledAt;

      final String? submissionWeekId = poolAnchor != null &&
              WeeklyPhotoSchedule.isInCollectionWindowSaoPaulo(poolAnchor)
          ? WeeklyPhotoSchedule.contestWeekIdSaoPaulo(poolAnchor)
          : null;

      final babyName = (baby?['name'] as String?) ?? '';
      final babyDisplayName = showBabyName ? _firstName(babyName) : '';
      final sexRaw = (baby?['sex'] as String?)?.trim().toUpperCase();
      final babySex = sexRaw == 'M' ? 'M' : 'F';

      final createdAt = memoryDate ?? publicEnabledAt;

      try {
        await FirestoreService.instance.upsertPublicMemoryDoc(
          docId: docId,
          data: {
            'memoryId': docId,
            'userId': uid,
            'babyId': babyCloud,
            'badgeId': badgeId,
            'badgeTitle': title,
            'photoUrl': photoUrl.isNotEmpty ? photoUrl : null,
            'publicDescription': (description == null || description.isEmpty) ? null : description,
            'description': (description == null || description.isEmpty) ? null : description,
            'babyDisplayName': babyDisplayName.isEmpty ? null : babyDisplayName,
            'babySex': babySex,
            'babyAgeLabel': (babyAgeAtMoment == null || babyAgeAtMoment.isEmpty) ? null : babyAgeAtMoment,
            if (createdAt != null) 'createdAt': createdAt.toIso8601String(),
            'publicEnabledAt': publicEnabledAt?.toIso8601String(),
            'submissionWeekId': submissionWeekId,
            'selectedAsWeeklyPhoto': ((row['weekly_photo_winner'] as int?) ?? 0) == 1,
            'weekId': (row['weekly_photo_week_id'] as String?)?.trim(),
            'showBabyFirstNameWhenPublic': showBabyName,
          },
        );
      } catch (e, st) {
        debugPrint('WeeklyPhotoPublicSync: upsertPublicMemoryDoc failed: $e\n$st');
      }
    } catch (e, st) {
      debugPrint('WeeklyPhotoPublicSync.syncBadgeMemory failed: $e\n$st');
    }
  }

  static void syncBadgeMemorySoon({required int localBabyId, required String badgeId}) {
    if (!_authed || kIsWeb) return;
    unawaited(
      syncBadgeMemory(localBabyId: localBabyId, badgeId: badgeId).catchError((e, st) {
        debugPrint('WeeklyPhotoPublicSync.syncBadgeMemorySoon: $e\n$st');
      }),
    );
  }
}
