// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:facebaby_flutter/app/face_baby_app.dart';
import 'package:facebaby_flutter/firebase_options.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // Tests run in a Dart VM where sqflite needs an explicit factory.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App starts (smoke test)', (WidgetTester tester) async {
    await tester.pumpWidget(const FaceBabyApp());
    await tester.pump();

    // Keep this test resilient: DB/plugins may be async; we only assert the app mounted.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
