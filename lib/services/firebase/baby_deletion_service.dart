import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_database.dart';
import 'firestore_service.dart';
import 'firestore_user_repository.dart';
import 'storage_service.dart';

class BabyDeletionService {
  BabyDeletionService._();

  static final BabyDeletionService instance = BabyDeletionService._();

  Future<void> deleteBabyEverywhere({required int localBabyId}) async {
    // Cloud best-effort.
    try {
      await _deleteCloud(localBabyId: localBabyId);
    } catch (e, st) {
      debugPrint('BabyDeletionService cloud delete failed: $e\n$st');
    }

    // Local always.
    await AppDatabase.instance.deleteBaby(babyId: localBabyId);
  }

  Future<void> _deleteCloud({required int localBabyId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (kIsWeb) {
      // still ok, but local wipe isn't relevant
    }

    final row = await AppDatabase.instance.getBabyById(localBabyId);
    final cloudId = (row?['cloud_id'] as String?)?.trim();
    if (cloudId == null || cloudId.isEmpty) return;

    // New schema
    try {
      await FirestoreUserRepository.instance.babiesCol(user.uid).doc(cloudId).delete();
    } catch (_) {}

    // Legacy schema (current app still writes here)
    final fs = FirestoreService.instance;

    // Eventos do bebê ficam em users/{uid}/events com baby_id.
    while (true) {
      final snap = await fs.eventsCol().where('baby_id', isEqualTo: cloudId).limit(250).get();
      if (snap.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    try {
      await fs.deleteBaby(cloudId);
    } catch (_) {}

    // Storage photos for this baby
    try {
      await StorageService.instance.deleteFolder('users/${user.uid}/babies/$cloudId');
    } catch (_) {}
  }
}

