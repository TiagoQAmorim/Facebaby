import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_database.dart';
import 'firestore_service.dart';
import 'profile_cloud_sync.dart';

class JournalCloudSync {
  JournalCloudSync._();

  static bool get _authed => FirebaseAuth.instance.currentUser != null;

  static void pushLocalSoon({required int localBabyId, required DateTime day}) {
    if (!_authed || kIsWeb) return;
    unawaited(pushLocal(localBabyId: localBabyId, day: day));
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<void> pushLocal({required int localBabyId, required DateTime day}) async {
    if (!_authed || kIsWeb) return;
    try {
      await ProfileCloudSync.pushBaby(localBabyId);
      final baby = await AppDatabase.instance.getBabyById(localBabyId);
      final babyCloud = (baby?['cloud_id'] as String?)?.trim();
      if (babyCloud == null || babyCloud.isEmpty) return;

      final text = await AppDatabase.instance.getDailyJournalText(babyId: localBabyId, calendarDay: day);
      await FirestoreService.instance.upsertDailyJournal(
        babyId: babyCloud,
        dayKey: _dayKey(day),
        text: text,
      );
    } catch (e, st) {
      debugPrint('JournalCloudSync.pushLocal failed: $e\n$st');
    }
  }
}

