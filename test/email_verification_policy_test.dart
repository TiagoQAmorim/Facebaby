import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:facebaby_flutter/services/firebase/email_verification_policy.dart';

void main() {
  test('mustVerify is false when email verified', () {
    final user = _FakeUser(
      emailVerified: true,
      providers: [EmailAuthProvider.PROVIDER_ID],
    );
    expect(EmailVerificationPolicy.mustVerify(user), isFalse);
  });

  test('mustVerify is true for unverified password account', () {
    final user = _FakeUser(
      emailVerified: false,
      providers: [EmailAuthProvider.PROVIDER_ID],
    );
    expect(EmailVerificationPolicy.mustVerify(user), isTrue);
  });

  test('mustVerify is false for Google-only account', () {
    final user = _FakeUser(
      emailVerified: false,
      providers: const ['google.com'],
    );
    expect(EmailVerificationPolicy.mustVerify(user), isFalse);
  });

  test('mustVerify is false for Apple-only account', () {
    final user = _FakeUser(
      emailVerified: false,
      providers: const ['apple.com'],
    );
    expect(EmailVerificationPolicy.mustVerify(user), isFalse);
  });
}

class _FakeUser implements User {
  _FakeUser({
    required this.emailVerified,
    required this.providers,
  });

  @override
  final bool emailVerified;

  final List<String> providers;

  @override
  List<UserInfo> get providerData =>
      providers.map((id) => _FakeUserInfo(id)).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserInfo implements UserInfo {
  _FakeUserInfo(this.providerId);

  @override
  final String providerId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
