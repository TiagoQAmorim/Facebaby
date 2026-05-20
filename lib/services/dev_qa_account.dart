import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase/auth_service.dart';
import 'premium/premium_service.dart';

/// Conta de testes com Premium vitalício (só em debug ou `--dart-define=FACEBABY_QA_TOOLS=true`).
abstract final class DevQaAccount {
  DevQaAccount._();

  /// E-mail/senha fixos para QA manual e para o atalho em Mais › Ferramentas QA.
  static const email = 'qa.facebaby@test.com';
  static const password = 'FaceBabyTest1!';

  static bool get available => PremiumService.qaToolsEnabled;

  /// Entra (ou regista) a conta teste e activa Premium na nuvem + override local opcional.
  static Future<void> signInOrCreate({bool forceDebugPremium = true}) async {
    if (!available) {
      throw StateError('QA tools disabled');
    }

    final auth = AuthService.instance;
    try {
      await auth.signInWithEmail(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      final code = e.code;
      if (code == 'user-not-found' ||
          code == 'invalid-credential' ||
          code == 'invalid-login-credentials' ||
          code == 'wrong-password') {
        await auth.registerWithEmail(
          email: email,
          password: password,
          displayName: 'Conta Teste QA',
        );
      } else {
        rethrow;
      }
    }

    await PremiumService.instance.grantLifetimePremiumForCurrentUser();
    if (forceDebugPremium) {
      await PremiumService.instance.setDebugPremiumForced(true);
    }
    debugPrint(
      'DevQaAccount: signed in as $email — premiumLifetime=true (Firestore + local)',
    );
  }
}
