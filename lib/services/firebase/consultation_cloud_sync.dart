import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_database.dart';
import 'firestore_service.dart';
import 'profile_cloud_sync.dart';

class ConsultationCloudSync {
  ConsultationCloudSync._();

  static bool get _authed => FirebaseAuth.instance.currentUser != null;

  static void pushLocalSoon({required int localBabyId, required int localConsultationId}) {
    if (!_authed || kIsWeb) return;
    unawaited(pushLocal(localBabyId: localBabyId, localConsultationId: localConsultationId));
  }

  static Future<void> pushLocal({required int localBabyId, required int localConsultationId}) async {
    if (!_authed || kIsWeb) return;
    try {
      await ProfileCloudSync.pushBaby(localBabyId);
      final baby = await AppDatabase.instance.getBabyById(localBabyId);
      final babyCloud = (baby?['cloud_id'] as String?)?.trim();
      if (babyCloud == null || babyCloud.isEmpty) return;

      final row = await AppDatabase.instance.getConsultation(id: localConsultationId, babyId: localBabyId);
      if (row == null) return;
      final cloudId = (row['cloud_id'] as String?)?.trim();
      final title = (row['title'] as String?)?.trim() ?? '';
      final occurredAt = DateTime.tryParse((row['occurred_at'] as String?) ?? '');
      if (title.isEmpty || occurredAt == null) return;

      if (cloudId == null || cloudId.isEmpty) {
        final createdId = await FirestoreService.instance.createConsultation(
          babyId: babyCloud,
          title: title,
          occurredAt: occurredAt,
          notes: row['notes'] as String?,
          phone: row['phone'] as String?,
          address: row['address'] as String?,
        );
        // Grava no SQLite para mapear nas próximas syncs.
        final db = await AppDatabase.instance.database;
        await db.update(
          'consultations',
          {'cloud_id': createdId},
          where: 'id = ? AND baby_id = ?',
          whereArgs: [localConsultationId, localBabyId],
        );
      } else {
        await FirestoreService.instance.updateConsultation(
          babyId: babyCloud,
          consultationId: cloudId,
          patch: {
            'title': title,
            'notes': row['notes'],
            'phone': row['phone'],
            'address': row['address'],
            'occurred_at': occurredAt.toIso8601String(),
          },
        );
      }
    } catch (e, st) {
      debugPrint('ConsultationCloudSync.pushLocal failed: $e\n$st');
    }
  }
}

