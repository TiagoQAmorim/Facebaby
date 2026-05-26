import 'package:facebaby_flutter/app/app_locale.dart';
import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/models/ai/ai_profile_model.dart';
import 'package:facebaby_flutter/repositories/ai/ai_profile_repository.dart';
import 'package:facebaby_flutter/pages/ai/ai_nanny_screen.dart';
import 'package:facebaby_flutter/widgets/ai_baby_history_form.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:facebaby_flutter/firebase_options.dart';

import 'helpers/tablet_test_harness.dart';

Widget _testApp(Widget child) {
  return tabletTestApp(child: child, size: const Size(400, 800));
}

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
    kAppLanguage.setLang(AppLang.pt);
  });

  group('Histórico do Bebê — validação', () {
    test('limite de armazenamento é 1500 caracteres', () {
      expect(AiProfile.maxHistoryLength, 1500);
    });

    test('Firestore usa coleção ai_profiles/{userId}', () {
      expect(AiProfileRepository.collectionName, 'ai_profiles');
    });

    testWidgets('botão Perfil da IA aparece na tela IA Babá', (tester) async {
      await tester.pumpWidget(_testApp(const AiNannyScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Perfil da IA'), findsOneWidget);
    });

    testWidgets('campo limita em 1500 caracteres', (tester) async {
      await tester.pumpWidget(
        _testApp(
          const Scaffold(
            body: AiBabyHistoryForm(showActions: false, embedded: true),
          ),
        ),
      );
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, 1500);
    });

    testWidgets('formulário expõe salvar e limpar histórico', (tester) async {
      await tester.pumpWidget(
        _testApp(
          const Scaffold(
            body: AiBabyHistoryForm(showActions: true),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Salvar histórico'), findsOneWidget);
      expect(find.text('Limpar histórico'), findsOneWidget);
    });
  });
}
