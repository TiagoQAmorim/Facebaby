import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_database.dart';

/// Evita misturar SQLite de uma conta com outro UID Firebase (ex.: apagar conta e
/// registar de novo com o mesmo e-mail).
abstract final class AuthLocalScope {
  AuthLocalScope._();

  static const _boundUidKey = 'bound_firebase_auth_uid';

  static Future<void> resetLocalIfAuthUserChanged() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_boundUidKey);
    if (previous != null && previous != uid) {
      await AppDatabase.instance.wipeLocalCache();
    }
    await prefs.setString(_boundUidKey, uid);
  }

  static Future<void> clearBinding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_boundUidKey);
  }
}
