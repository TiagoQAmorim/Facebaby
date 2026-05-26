import 'package:facebaby_admin/app.dart';
import 'package:facebaby_admin/services/admin_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';

import 'firebase_options.dart';

/// Entry point for the FaceBaby Admin web panel (desktop/web).
///
/// Run: `flutter run -d chrome -t lib/main_admin.dart`
/// Build: `flutter build web --release -t lib/main_admin.dart --base-href /`
/// Deploy: `firebase deploy --only hosting:admin` (or `scripts/deploy_admin_web.ps1`)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kIsWeb) {
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    } catch (e) {
      debugPrint('FirebaseAuth.setPersistence(LOCAL): $e');
    }
  }

  await AdminAuthService.instance.init();
  runApp(const AdminApp());
}
