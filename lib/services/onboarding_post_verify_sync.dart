import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase/firestore_user_repository.dart';
import 'firebase/profile_cloud_sync.dart';
import 'onboarding_draft_store.dart';
import 'app_database.dart';

/// Sincroniza o cadastro local (feito antes da conta) após o e-mail ser confirmado.
abstract final class OnboardingPostVerifySync {
  OnboardingPostVerifySync._();

  static Future<bool> tryPushPendingProfileToCloud() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final draft = await OnboardingDraftStore.load();
    final localBabyId = draft.localBabyId;
    if (localBabyId == null) return false;

    try {
      await ProfileCloudSync.pushBaby(localBabyId);
      final baby = await AppDatabase.instance.getBabyById(localBabyId);
      final cloudId = (baby?['cloud_id'] as String?)?.trim();
      if (cloudId == null || cloudId.isEmpty) return false;

      await FirestoreUserRepository.instance.saveUserProfile(uid, {
        'name': FirebaseAuth.instance.currentUser?.displayName,
        'email': FirebaseAuth.instance.currentUser?.email,
      });
      await FirestoreUserRepository.instance.setSelectedBabyId(uid, cloudId);
      await OnboardingDraftStore.clear();
      return true;
    } catch (e, st) {
      debugPrint('OnboardingPostVerifySync.tryPushPendingProfileToCloud: $e\n$st');
      return false;
    }
  }
}
