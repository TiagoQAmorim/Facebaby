import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_database.dart';
import 'firestore_service.dart';
import 'profile_cloud_sync.dart';

class SymptomCloudSync {
  SymptomCloudSync._();

  static bool get _authed => FirebaseAuth.instance.currentUser != null;

  static void pushLocalSoon({required int localBabyId, required int localSymptomId}) {
    if (!_authed || kIsWeb) return;
    unawaited(pushLocal(localBabyId: localBabyId, localSymptomId: localSymptomId));
  }

  static Future<void> pushLocal({required int localBabyId, required int localSymptomId}) async {
    if (!_authed || kIsWeb) return;
    try {
      await ProfileCloudSync.pushBaby(localBabyId);
      final baby = await AppDatabase.instance.getBabyById(localBabyId);
      final babyCloud = (baby?['cloud_id'] as String?)?.trim();
      if (babyCloud == null || babyCloud.isEmpty) return;

      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'symptom_reports',
        where: 'id = ? AND baby_id = ?',
        whereArgs: [localSymptomId, localBabyId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;

      final occurredAt = DateTime.tryParse((row['occurred_at'] as String?) ?? '');
      if (occurredAt == null) return;

      final cloudId = (row['cloud_id'] as String?)?.trim();
      final med = (row['medication_note'] as String?)?.trim();
      final fever = ((row['fever'] as num?)?.toInt() ?? 0) != 0;
      final tempCelsius = (row['temp_celsius'] as num?)?.toDouble();
      final crying = ((row['crying'] as num?)?.toInt() ?? 0) != 0;
      final pain = ((row['pain'] as num?)?.toInt() ?? 0) != 0;
      final colic = ((row['colic'] as num?)?.toInt() ?? 0) != 0;
      final reflux = ((row['reflux'] as num?)?.toInt() ?? 0) != 0;
      final other = (row['other_note'] as String?)?.trim();

      if (cloudId == null || cloudId.isEmpty) {
        final createdId = await FirestoreService.instance.createSymptomReport(
          babyId: babyCloud,
          occurredAt: occurredAt,
          medicationNote: med,
          fever: fever,
          tempCelsius: tempCelsius,
          crying: crying,
          pain: pain,
          colic: colic,
          reflux: reflux,
          otherNote: other,
        );
        await AppDatabase.instance.setSymptomReportCloudId(
          id: localSymptomId,
          babyId: localBabyId,
          cloudId: createdId,
        );
      } else {
        await FirestoreService.instance.updateSymptomReport(
          babyId: babyCloud,
          symptomReportId: cloudId,
          occurredAt: occurredAt,
          medicationNote: med,
          fever: fever,
          tempCelsius: tempCelsius,
          crying: crying,
          pain: pain,
          colic: colic,
          reflux: reflux,
          otherNote: other,
        );
      }
    } catch (e, st) {
      debugPrint('SymptomCloudSync.pushLocal failed: $e\n$st');
    }
  }

  /// Apaga o evento em `users/{uid}/events/{cloud_id}` antes de remover o registo local.
  static Future<void> deleteRemoteIfExists({required int localBabyId, required int localSymptomId}) async {
    if (!_authed || kIsWeb) return;
    try {
      final row = await AppDatabase.instance.getSymptomReport(id: localSymptomId, babyId: localBabyId);
      final cid = (row?['cloud_id'] as String?)?.trim();
      if (cid == null || cid.isEmpty) return;
      await FirestoreService.instance.deleteEvent(cid);
    } catch (e, st) {
      debugPrint('SymptomCloudSync.deleteRemoteIfExists failed: $e\n$st');
    }
  }
}
