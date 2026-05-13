import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app/face_baby_app.dart';
import 'app/app_locale.dart';
import 'firebase_options.dart';
import 'services/notification_timezone.dart';
import 'services/premium/premium_service.dart';
import 'utils/platform_info.dart';

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

  if (!kIsWeb) {
    await NotificationTimezone.init();
  }

  await kAppLanguage.loadInitialLocale();

  await PremiumService.instance.initialize();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWebBasicWebWorker;
    debugPrint('BOOT_WEB_SQLITE=databaseFactoryFfiWebBasicWebWorker');
  } else if (isDesktop) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    debugPrint('BOOT_DESKTOP_SQLITE=databaseFactoryFfi');
  } else {
    debugPrint('BOOT_MOBILE_SQLITE=sqflite_default');
  }

  runApp(const FaceBabyApp());
}
