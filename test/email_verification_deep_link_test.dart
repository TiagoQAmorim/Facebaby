import 'package:facebaby_flutter/services/firebase/email_verification_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extractOobCode from Firebase auth action URL', () {
    final uri = Uri.parse(
      'https://facebaby-afc41.firebaseapp.com/__/auth/action'
      '?mode=verifyEmail&oobCode=ABC123&lang=pt',
    );
    expect(EmailVerificationDeepLink.extractOobCode(uri), 'ABC123');
  });

  test('extractOobCode from hosting verify page', () {
    final uri = Uri.parse(
      'https://facebaby-afc41.firebaseapp.com/auth/verify-email.html'
      '?mode=verifyEmail&oobCode=XYZ',
    );
    expect(EmailVerificationDeepLink.extractOobCode(uri), 'XYZ');
  });

  test('returns null for wrong mode', () {
    final uri = Uri.parse(
      'https://facebaby-afc41.firebaseapp.com/__/auth/action'
      '?mode=resetPassword&oobCode=ABC',
    );
    expect(EmailVerificationDeepLink.extractOobCode(uri), isNull);
  });
}
