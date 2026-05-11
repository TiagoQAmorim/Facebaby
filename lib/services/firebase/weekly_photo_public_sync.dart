import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_database.dart';
import '../premium/premium_service.dart';
import '../../utils/weekly_photo_schedule.dart';
import 'firestore_service.dart';

/// Escreve apenas campos seguros em `public_memories/{docId}` (sem dados médicos da mãe).
class WeeklyPhotoPublicSync {
  WeeklyPhotoPublicSync._();

  static bool get _authed => FirebaseAuth.instance.currentUser != null;

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

  static Future<void> syncBadgeMemory({
    required int localBabyId,
    required String badgeId,
  }) async {
    if (!_authed || kIsWeb) return;
    if (!PremiumService.instance.isPremium) return;

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
      final photoUrl = ((row['photo_path'] as String?) ?? '').trim();
      final photoB64 = ((row['photo_b64'] as String?) ?? '').trim();
      final hasPhoto = photoUrl.isNotEmpty || photoB64.isNotEmpty;

      final docId = publicDocId(ownerUid: uid, babyCloudId: babyCloud, badgeId: badgeId);

      if (!isPublic || !hasPhoto) {
        await FirestoreService.instance.deletePublicMemoryDoc(docId);
        return;
      }

      if (photoUrl.isEmpty) {
        await FirestoreService.instance.deletePublicMemoryDoc(docId);
        return;
      }

      final title = (row['title'] as String?)?.trim() ?? '—';
      final description = (row['description'] as String?)?.trim();
      final memoryDateStr = (row['memory_date'] as String?)?.trim();
      final memoryDate = DateTime.tryParse(memoryDateStr ?? '') ?? DateTime.now();
      final babyAgeAtMoment = (row['baby_age_at_moment'] as String?)?.trim();
      final showBabyName = ((row['show_baby_name_public'] as int?) ?? 1) == 1;
      final peRaw = (row['public_enabled_at'] as String?)?.trim();
      final publicEnabledAt = peRaw != null && peRaw.isNotEmpty ? DateTime.tryParse(peRaw) : null;

      final submissionWeekId =
          publicEnabledAt != null && WeeklyPhotoSchedule.isInCollectionWindow(publicEnabledAt)
              ? WeeklyPhotoSchedule.contestWeekId(publicEnabledAt)
              : null;

      final babyName = (baby?['name'] as String?) ?? '';
      final babyDisplayName = showBabyName ? _firstName(babyName) : '';
      final sexRaw = (baby?['sex'] as String?)?.trim().toUpperCase();
      final babySex = sexRaw == 'M' ? 'M' : 'F';

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
          'babyDisplayName': babyDisplayName.isEmpty ? null : babyDisplayName,
          'babySex': babySex,
          'babyAgeLabel': (babyAgeAtMoment == null || babyAgeAtMoment.isEmpty) ? null : babyAgeAtMoment,
          'createdAt': memoryDate.toIso8601String(),
          'publicEnabledAt': publicEnabledAt?.toIso8601String(),
          'submissionWeekId': submissionWeekId,
          'selectedAsWeeklyPhoto': ((row['weekly_photo_winner'] as int?) ?? 0) == 1,
          'weekId': (row['weekly_photo_week_id'] as String?)?.trim(),
          'showBabyFirstNameWhenPublic': showBabyName,
        },
      );
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
