import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Resultado ao processar um link de verificação de e-mail (Firebase oobCode).
enum EmailVerificationLinkResult {
  notApplicable,
  applied,
  alreadyVerified,
}

/// Extrai e aplica `oobCode` de links Firebase / Hosting de confirmação de e-mail.
abstract final class EmailVerificationDeepLink {
  EmailVerificationDeepLink._();

  static String? extractOobCode(Uri uri) {
    final mode = (uri.queryParameters['mode'] ?? '').toLowerCase();
    if (mode.isNotEmpty && mode != 'verifyemail') return null;

    var code = uri.queryParameters['oobCode'] ?? uri.queryParameters['oob_code'];
    if (code != null && code.isNotEmpty) return code;

    final href = uri.toString();
    final match =
        RegExp(r'[?&#]oobCode=([^&#]+)', caseSensitive: false).firstMatch(href) ??
            RegExp(r'[?&#]oob_code=([^&#]+)', caseSensitive: false).firstMatch(href);
    if (match == null) return null;
    return Uri.decodeComponent(match.group(1)!);
  }

  static Future<EmailVerificationLinkResult> tryApply(Uri uri) async {
    final code = extractOobCode(uri);
    if (code == null || code.isEmpty) {
      return EmailVerificationLinkResult.notApplicable;
    }

    try {
      final info = await FirebaseAuth.instance.checkActionCode(code);
      final op = '${info.operation}'.toUpperCase();
      if (op.isNotEmpty && op != 'VERIFY_EMAIL') {
        return EmailVerificationLinkResult.notApplicable;
      }
      await FirebaseAuth.instance.applyActionCode(code);
      await _reloadCurrentUser();
      return EmailVerificationLinkResult.applied;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-action-code') {
        await _reloadCurrentUser();
        if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
          return EmailVerificationLinkResult.alreadyVerified;
        }
        return EmailVerificationLinkResult.alreadyVerified;
      }
      debugPrint('EmailVerificationDeepLink: ${e.code} ${e.message}');
      rethrow;
    }
  }

  static Future<void> _reloadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed != null && refreshed.emailVerified) {
      await refreshed.getIdToken(true);
    }
  }
}
