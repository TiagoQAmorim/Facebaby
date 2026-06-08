import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/firestore_user_repository.dart';

/// First-time app tour completion (local + Firestore user profile).
class AppTourService {
  AppTourService._();

  static final AppTourService instance = AppTourService._();

  static const _prefCompleted = 'facebaby_app_tour_completed_v1';
  static const _firestoreField = 'appTourCompleted';

  Future<bool> isCompletedLocally() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefCompleted) ?? false;
  }

  Future<bool> isCompletedRemotely(String? uid) async {
    if (uid == null || uid.isEmpty) return false;
    try {
      final profile = await FirestoreUserRepository.instance.getUserProfile(uid);
      return profile?[_firestoreField] == true;
    } catch (e, st) {
      debugPrint('AppTourService.isCompletedRemotely: $e\n$st');
      return false;
    }
  }

  Future<bool> shouldShowForUser(String? uid, {bool force = false}) async {
    if (force) return true;
    if (await isCompletedLocally()) return false;
    if (await isCompletedRemotely(uid)) {
      await _markCompletedLocally();
      return false;
    }
    return true;
  }

  Future<void> markCompleted() async {
    await _markCompletedLocally();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      await FirestoreUserRepository.instance.saveUserProfile(uid, {
        _firestoreField: true,
        'appTourCompletedAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e, st) {
      debugPrint('AppTourService.markCompleted remote: $e\n$st');
    }
  }

  Future<void> _markCompletedLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefCompleted, true);
  }
}
