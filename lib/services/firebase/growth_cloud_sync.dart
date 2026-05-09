import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_database.dart';
import 'firestore_service.dart';
import 'profile_cloud_sync.dart';

class GrowthCloudSync {
  GrowthCloudSync._();

  static bool get _authed => FirebaseAuth.instance.currentUser != null;

  static void pushLocalSoon({required int localBabyId, required int localGrowthId}) {
    if (!_authed || kIsWeb) return;
    unawaited(pushLocal(localBabyId: localBabyId, localGrowthId: localGrowthId));
  }

  static Future<void> pushLocal({required int localBabyId, required int localGrowthId}) async {
    if (!_authed || kIsWeb) return;
    try {
      await ProfileCloudSync.pushBaby(localBabyId);
      final baby = await AppDatabase.instance.getBabyById(localBabyId);
      final babyCloud = (baby?['cloud_id'] as String?)?.trim();
      if (babyCloud == null || babyCloud.isEmpty) return;

      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'growth_records',
        where: 'id = ? AND baby_id = ?',
        whereArgs: [localGrowthId, localBabyId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;

      final cloudId = (row['cloud_id'] as String?)?.trim();
      final kind = (row['kind'] as String?)?.trim();
      final value = (row['value'] is num) ? (row['value'] as num).toDouble() : double.tryParse('${row['value']}');
      final measuredAt = DateTime.tryParse((row['measured_at'] as String?) ?? '');
      if (kind == null || kind.isEmpty || value == null || measuredAt == null) return;

      if (cloudId == null || cloudId.isEmpty) {
        final createdId = await FirestoreService.instance.createGrowthRecord(
          babyId: babyCloud,
          kind: kind,
          value: value,
          measuredAt: measuredAt,
        );
        await db.update(
          'growth_records',
          {'cloud_id': createdId},
          where: 'id = ? AND baby_id = ?',
          whereArgs: [localGrowthId, localBabyId],
        );
      } else {
        await FirestoreService.instance.updateGrowthRecord(
          babyId: babyCloud,
          growthId: cloudId,
          patch: {
            'kind': kind,
            'value': value,
            'measured_at': measuredAt.toIso8601String(),
          },
        );
      }
    } catch (e, st) {
      debugPrint('GrowthCloudSync.pushLocal failed: $e\n$st');
    }
  }
}

