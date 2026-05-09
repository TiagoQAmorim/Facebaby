import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_database.dart';
import 'firestore_service.dart';
import 'profile_cloud_sync.dart';

class FeedingCloudSync {
  FeedingCloudSync._();

  static bool get _authed => FirebaseAuth.instance.currentUser != null;

  static void pushLocalSoon({required int localBabyId, required int localFeedingId}) {
    if (!_authed || kIsWeb) return;
    unawaited(pushLocal(localBabyId: localBabyId, localFeedingId: localFeedingId));
  }

  static Future<void> pushLocal({required int localBabyId, required int localFeedingId}) async {
    if (!_authed || kIsWeb) return;
    try {
      await ProfileCloudSync.pushBaby(localBabyId);
      final baby = await AppDatabase.instance.getBabyById(localBabyId);
      final babyCloud = (baby?['cloud_id'] as String?)?.trim();
      if (babyCloud == null || babyCloud.isEmpty) return;

      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'feedings',
        where: 'id = ? AND baby_id = ?',
        whereArgs: [localFeedingId, localBabyId],
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
        final createdId = await FirestoreService.instance.createFeeding(
          babyId: babyCloud,
          startedAt: startedAt,
          endedAt: endedAt,
          durationSec: duration,
          side: row['side'] as String?,
          type: row['type'] as String?,
          quantityMl: (row['quantity_ml'] is num) ? (row['quantity_ml'] as num).toDouble() : null,
          note: row['note'] as String?,
        );
        await db.update(
          'feedings',
          {'cloud_id': createdId},
          where: 'id = ? AND baby_id = ?',
          whereArgs: [localFeedingId, localBabyId],
        );
      } else {
        await FirestoreService.instance.updateFeeding(
          babyId: babyCloud,
          feedingId: cloudId,
          patch: {
            'started_at': startedAt.toIso8601String(),
            'ended_at': endedAt.toIso8601String(),
            'duration_sec': duration,
            'side': row['side'],
            'type': row['type'],
            'quantity_ml': row['quantity_ml'],
            'note': row['note'],
          },
        );
      }
    } catch (e, st) {
      debugPrint('FeedingCloudSync.pushLocal failed: $e\n$st');
    }
  }
}

