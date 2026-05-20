import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:facebaby_flutter/firebase_options.dart';
import 'package:facebaby_flutter/pages/auth/login_page.dart';
import 'package:facebaby_flutter/pages/auth/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/tablet_test_harness.dart';

/// Renders ecrãs **reais** do app em tamanho tablet 10".
///
/// Gerar PNGs (primeira vez ou após mudar UI):
///   flutter test --update-goldens test/tablet_golden_test.dart
///
/// Ver ficheiros em `test/goldens/tablet_10/`.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> pumpUntilSettled(WidgetTester tester, {int maxFrames = 120}) async {
    for (var i = 0; i < maxFrames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (!tester.binding.hasScheduledFrame) break;
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  group('tablet 10" — renders reais (golden)', () {
    testWidgets('login landscape', (tester) async {
      await tester.binding.setSurfaceSize(tablet10Landscape);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        tabletTestApp(size: tablet10Landscape, child: const LoginPage()),
      );
      await pumpUntilSettled(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('tablet_10/login_landscape.png'),
      );
    });

    testWidgets('login portrait', (tester) async {
      await tester.binding.setSurfaceSize(tablet10Portrait);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        tabletTestApp(size: tablet10Portrait, child: const LoginPage()),
      );
      await pumpUntilSettled(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('tablet_10/login_portrait.png'),
      );
    });

    testWidgets('onboarding welcome landscape', (tester) async {
      await tester.binding.setSurfaceSize(tablet10Landscape);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        tabletTestApp(
          size: tablet10Landscape,
          child: const OnboardingPage(),
        ),
      );
      await pumpUntilSettled(tester, maxFrames: 200);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('tablet_10/onboarding_welcome_landscape.png'),
      );
    });

    testWidgets('onboarding welcome portrait', (tester) async {
      await tester.binding.setSurfaceSize(tablet10Portrait);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        tabletTestApp(
          size: tablet10Portrait,
          child: const OnboardingPage(),
        ),
      );
      await pumpUntilSettled(tester, maxFrames: 200);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('tablet_10/onboarding_welcome_portrait.png'),
      );
    });
  });
}
