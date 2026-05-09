import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_database.dart';
import 'firestore_service.dart';
import 'profile_cloud_sync.dart';

class DiaperCloudSync {
  DiaperCloudSync._();

  static bool get _authed => FirebaseAuth.instance.currentUser != null;

  static void pushLocalSoon({required int localBabyId, required int localDiaperId}) {
    if (!_authed || kIsWeb) return;
    unawaited(pushLocal(localBabyId: localBabyId, localDiaperId: localDiaperId));
  }

  static Future<void> pushLocal({required int localBabyId, required int localDiaperId}) async {
    if (!_authed || kIsWeb) return;
    try {
      await ProfileCloudSync.pushBaby(localBabyId);
      final baby = await AppDatabase.instance.getBabyById(localBabyId);
      final babyCloud = (baby?['cloud_id'] as String?)?.trim();
      if (babyCloud == null || babyCloud.isEmpty) return;

      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'diapers',
        where: 'id = ? AND baby_id = ?',
        whereArgs: [localDiaperId, localBabyId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;

      final cloudId = (row['cloud_id'] as String?)?.trim();
      final changedAt = DateTime.tryParse((row['changed_at'] as String?) ?? '');
      final kind = (row['kind'] as String?)?.trim();
      if (changedAt == null || kind == null || kind.isEmpty) return;

      if (cloudId == null || cloudId.isEmpty) {
        final createdId = await FirestoreService.instance.createDiaper(
          babyId: babyCloud,
          changedAt: changedAt,
          kind: kind,
          note: row['note'] as String?,
        );
        await db.update(
          'diapers',
          {'cloud_id': createdId},
          where: 'id = ? AND baby_id = ?',
          whereArgs: [localDiaperId, localBabyId],
        );
      } else {
        await FirestoreService.instance.updateDiaper(
          babyId: babyCloud,
          diaperId: cloudId,
          patch: {
            'changed_at': changedAt.toIso8601String(),
            'kind': kind,
            'note': row['note'],
          },
        );
      }
    } catch (e, st) {
      debugPrint('DiaperCloudSync.pushLocal failed: $e\n$st');
    }
  }
}

