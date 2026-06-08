import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lembra que já houve sessão Firebase — evita mostrar login cedo demais no cold start.
abstract final class AuthSessionRestore {
  AuthSessionRestore._();

  static const _lastUidKey = 'facebaby_last_auth_uid_v1';

  static Future<void> recordSignedIn(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUidKey, user.uid);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastUidKey);
  }

  static Future<bool> hadPriorSession() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_lastUidKey);
    return uid != null && uid.isNotEmpty;
  }
}
