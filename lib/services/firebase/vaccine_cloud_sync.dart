import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_database.dart';
import 'firestore_service.dart';
import 'profile_cloud_sync.dart';

class VaccineCloudSync {
  VaccineCloudSync._();

  static bool get _authed => FirebaseAuth.instance.currentUser != null;

  static void pushLocalSoon({required int localBabyId, required int localVaccineId}) {
    if (!_authed || kIsWeb) return;
    unawaited(pushLocal(localBabyId: localBabyId, localVaccineId: localVaccineId));
  }

  static Future<void> pushLocal({required int localBabyId, required int localVaccineId}) async {
    if (!_authed || kIsWeb) return;
    try {
      await ProfileCloudSync.pushBaby(localBabyId);
      final baby = await AppDatabase.instance.getBabyById(localBabyId);
      final babyCloud = (baby?['cloud_id'] as String?)?.trim();
      if (babyCloud == null || babyCloud.isEmpty) return;

      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'vaccines',
        where: 'id = ? AND baby_id = ?',
        whereArgs: [localVaccineId, localBabyId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;

      final cloudId = (row['cloud_id'] as String?)?.trim();
      final name = (row['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return;

      DateTime? parseDt(Object? v) => v is String ? DateTime.tryParse(v) : null;
      final appliedAt = parseDt(row['applied_at']);
      final nextDueAt = parseDt(row['next_due_at']);

      if (cloudId == null || cloudId.isEmpty) {
        final createdId = await FirestoreService.instance.createVaccine(
          babyId: babyCloud,
          name: name,
          dose: row['dose'] as String?,
          appliedAt: appliedAt,
          nextDueAt: nextDueAt,
          notes: row['notes'] as String?,
        );
        await db.update(
          'vaccines',
          {'cloud_id': createdId},
          where: 'id = ? AND baby_id = ?',
          whereArgs: [localVaccineId, localBabyId],
        );
      } else {
        await FirestoreService.instance.updateVaccine(
          babyId: babyCloud,
          vaccineId: cloudId,
          patch: {
            'name': name,
            'dose': row['dose'],
            'applied_at': appliedAt?.toIso8601String(),
            'next_due_at': nextDueAt?.toIso8601String(),
            'notes': row['notes'],
          },
        );
      }
    } catch (e, st) {
      debugPrint('VaccineCloudSync.pushLocal failed: $e\n$st');
    }
  }
}

