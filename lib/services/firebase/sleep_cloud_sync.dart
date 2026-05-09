import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_database.dart';
import 'firestore_service.dart';
import 'profile_cloud_sync.dart';

class SleepCloudSync {
  SleepCloudSync._();

  static bool get _authed => FirebaseAuth.instance.currentUser != null;

  static void pushLocalSoon({required int localBabyId, required int localSleepId}) {
    if (!_authed || kIsWeb) return;
    unawaited(pushLocal(localBabyId: localBabyId, localSleepId: localSleepId));
  }

  static Future<void> pushLocal({required int localBabyId, required int localSleepId}) async {
    if (!_authed || kIsWeb) return;
    try {
      await ProfileCloudSync.pushBaby(localBabyId);
      final baby = await AppDatabase.instance.getBabyById(localBabyId);
      final babyCloud = (baby?['cloud_id'] as String?)?.trim();
      if (babyCloud == null || babyCloud.isEmpty) return;

      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'sleep_records',
        where: 'id = ? AND baby_id = ?',
        whereArgs: [localSleepId, localBabyId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;

      final cloudId = (row['cloud_id'] as String?)?.trim();
      DateTime? parseDt(Object? v) => v is String ? DateTime.tryParse(v) : null;
      final startedAt = parseDt(row['started_at']);
      final endedAt = parseDt(row['ended_at']);
      final duration = (row['duration_sec'] is num) ? (row['duration_sec'] as num).toInt() : null;
      if (startedAt == null || endedAt == null || duration == null) return;

      if (cloudId == null || cloudId.isEmpty) {
        final createdId = await FirestoreService.instance.createSleepRecord(
          babyId: babyCloud,
          startedAt: startedAt,
          endedAt: endedAt,
          durationSec: duration,
          quality: row['quality'] as String?,
          note: row['note'] as String?,
        );
        await db.update(
          'sleep_records',
          {'cloud_id': createdId},
          where: 'id = ? AND baby_id = ?',
          whereArgs: [localSleepId, localBabyId],
        );
      } else {
        await FirestoreService.instance.updateSleepRecord(
          babyId: babyCloud,
          sleepId: cloudId,
          patch: {
            'started_at': startedAt.toIso8601String(),
            'ended_at': endedAt.toIso8601String(),
            'duration_sec': duration,
            'quality': row['quality'],
            'note': row['note'],
          },
        );
      }
    } catch (e, st) {
      debugPrint('SleepCloudSync.pushLocal failed: $e\n$st');
    }
  }
}

