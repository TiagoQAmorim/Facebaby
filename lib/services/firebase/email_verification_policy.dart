import 'package:firebase_auth/firebase_auth.dart';

/// Conta e-mail/senha ainda não confirmou o e-mail.
class EmailVerificationRequiredException implements Exception {
  @override
  String toString() => 'Email verification required';
}

/// Reenvio de e-mail de verificação pedido demasiado cedo.
class EmailVerificationCooldownException implements Exception {
  EmailVerificationCooldownException(this.remaining);

  final Duration remaining;
}

/// Utilitários para verificação de e-mail (contas e-mail/senha).
abstract final class EmailVerificationPolicy {
  static const resendCooldown = Duration(seconds: 60);

  static bool usesEmailPasswordProvider(User user) {
    return user.providerData.any(
      (info) => info.providerId == EmailAuthProvider.PROVIDER_ID,
    );
  }

  /// Google/Apple passam; e-mail/senha exige [User.emailVerified].
  static bool mustVerify(User? user) {
    if (user == null) return false;
    if (user.emailVerified) return false;
    return usesEmailPasswordProvider(user);
  }
}
