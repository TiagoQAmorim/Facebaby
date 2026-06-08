import 'dart:convert';
import 'dart:developer' as developer;

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../utils/login_platform.dart';
import '../premium/premium_service.dart';
import 'auth_registration_exception.dart';
import 'auth_session_restore.dart';
import 'email_verification_policy.dart';
import 'google_sign_in_helpers.dart';

String _sha256Hex(String input) {
  final digest = sha256.convert(utf8.encode(input));
  return digest.toString();
}

/// Temporary: filter logs in DevTools / Logcat with this name.
const _kDebugGoogleSignInLogName = 'DEBUG Google Sign-In (TEMP)';

Future<void> _debugLogBeforeGoogleSignIn() async {
  final o = Firebase.app().options;
  developer.log(
    'Firebase options: appId=${o.appId} projectId=${o.projectId}',
    name: _kDebugGoogleSignInLogName,
  );
  try {
    final pkg = (await PackageInfo.fromPlatform()).packageName;
    developer.log('Application packageName=$pkg', name: _kDebugGoogleSignInLogName);
  } catch (e, st) {
    developer.log(
      'packageName unavailable: $e',
      name: _kDebugGoogleSignInLogName,
      error: e,
      stackTrace: st,
    );
  }
}

void _debugLogGoogleSignInFailure(Object error, StackTrace stackTrace, {required String step}) {
  final buf = StringBuffer('GoogleSignIn failure step=$step ');
  if (error is PlatformException) {
    buf.write(
      'code=${error.code} message=${error.message} details=${error.details}',
    );
  } else {
    buf.write('type=${error.runtimeType} details=$error');
  }
  developer.log(buf.toString(), name: _kDebugGoogleSignInLogName, error: error, stackTrace: stackTrace);
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  /// Após [signOut], o [AuthGate] mostra o onboarding sem esperar revalidação de sessão.
  bool _trustAuthNullImmediately = false;

  /// Consumido pelo [AuthGate] no próximo `authStateChanges(null)`.
  bool consumeTrustAuthNullImmediately() {
    final v = _trustAuthNullImmediately;
    _trustAuthNullImmediately = false;
    return v;
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const <String>[
      'email',
      'profile',
      'openid',
    ],
    serverClientId: effectiveGoogleWebClientId,
  );

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool _isGoogleUser(User user) {
    return user.providerData.any(
      (info) => info.providerId == GoogleAuthProvider.PROVIDER_ID,
    );
  }

  Future<void> _recordSignedIn(User? user) async {
    if (user == null) return;
    await AuthSessionRestore.recordSignedIn(user);
  }

  /// Reconecta Google Sign-In silencioso quando Firebase ainda não restaurou a sessão.
  Future<void> tryRestoreGoogleSession() async {
    try {
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final user = _auth.currentUser;
      if (user == null) {
        final cred = await _auth.signInWithCredential(credential);
        await _recordSignedIn(cred.user);
        return;
      }

      if (!_isGoogleUser(user)) return;
      await user.getIdToken(true);
      await user.reload();
    } catch (e, st) {
      developer.log(
        'tryRestoreGoogleSession (non-fatal): $e',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      final user = _auth.currentUser;
      if (user == null) return;
      try {
        await user.getIdToken(true);
      } catch (_) {}
    }
  }

  /// Espera a sessão Firebase no disco (Samsung/Android após reiniciar o telemóvel).
  Future<User?> waitForPersistedUser({
    required Duration pollInterval,
    required int maxAttempts,
    void Function(int attempt)? onAttempt,
  }) async {
    User? user;
    for (var i = 0; i < maxAttempts; i++) {
      onAttempt?.call(i);
      user = _auth.currentUser;
      if (user != null) return user;
      if (i > 0) {
        await Future<void>.delayed(pollInterval);
      }
      if (i > 0 && i % 5 == 0) {
        await tryRestoreGoogleSession();
        user = _auth.currentUser;
        if (user != null) return user;
      }
    }
    return _auth.currentUser;
  }

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  /// Garante que o e-mail ainda não tem conta Firebase (e-mail/senha ou outro provedor).
  ///
  /// Lança [EmailAlreadyRegisteredException] se o e-mail já tiver registo, ou
  /// [FirebaseAuthException] com `invalid-email`.
  Future<void> ensureEmailAvailableForRegistration(String email) async {
    final normalized = normalizeEmail(email);
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Invalid email',
      );
    }

    try {
      final methods = await _auth.fetchSignInMethodsForEmail(normalized);
      if (methods.isNotEmpty) {
        throw EmailAlreadyRegisteredException(methods);
      }
    } on EmailAlreadyRegisteredException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        rethrow;
      }
      // Com proteção contra enumeração, o fetch pode falhar; o createUser valida depois.
    }
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final normalized = normalizeEmail(email);
    await ensureEmailAvailableForRegistration(normalized);

    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: normalized,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use' ||
          e.code == 'credential-already-in-use' ||
          e.code == 'account-exists-with-different-credential') {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: e.message,
        );
      }
      rethrow;
    }

    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      await cred.user?.updateDisplayName(name);
      await cred.user?.reload();
    }
    try {
      await cred.user?.sendEmailVerification(_emailActionCodeSettings);
      _lastVerificationEmailSent = DateTime.now();
    } catch (e, st) {
      developer.log(
        'sendEmailVerification after register failed',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
    }
    await _recordSignedIn(cred.user);
    return cred;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _recordSignedIn(cred.user);
    return cred;
  }

  Future<UserCredential> signInWithGoogle() async {
    await _debugLogBeforeGoogleSignIn();

    GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignIn.signIn();
    } catch (e, st) {
      _debugLogGoogleSignInFailure(e, st, step: 'signIn');
      rethrow;
    }
    if (googleUser == null) {
      developer.log(
        'GoogleSignIn.signIn returned null (user dismissed)',
        name: _kDebugGoogleSignInLogName,
      );
      throw StateError('Login cancelado');
    }

    GoogleSignInAuthentication googleAuth;
    try {
      googleAuth = await googleUser.authentication;
    } catch (e, st) {
      _debugLogGoogleSignInFailure(e, st, step: 'authentication');
      rethrow;
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    try {
      final cred = await _auth.signInWithCredential(credential);
      await _recordSignedIn(cred.user);
      return cred;
    } on FirebaseAuthException catch (e, st) {
      developer.log(
        'FirebaseAuth signInWithCredential code=${e.code} message=${e.message}',
        name: _kDebugGoogleSignInLogName,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Sign in with Apple (iOS only). Uses Firebase `OAuthProvider('apple.com')`.
  Future<UserCredential> signInWithApple() async {
    if (!isIOSDevice) {
      throw StateError('APPLE_UNAVAILABLE_PLATFORM');
    }

    final rawNonce = generateNonce();
    final nonce = _sha256Hex(rawNonce);

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('APPLE_MISSING_ID_TOKEN');
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
      );

      try {
        final cred = await _auth.signInWithCredential(oauthCredential);
        await _recordSignedIn(cred.user);
        return cred;
      } on FirebaseAuthException catch (e, st) {
        developer.log(
          'FirebaseAuth Apple signIn code=${e.code} message=${e.message}',
          name: 'Apple Sign-In',
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      developer.log(
        'Apple authorization code=${e.code}',
        name: 'Apple Sign-In',
        error: e,
      );
      if (e.code == AuthorizationErrorCode.canceled) {
        throw StateError('Login cancelado');
      }
      throw StateError('APPLE_AUTH_FAILED');
    } on SignInWithAppleNotSupportedException catch (e, st) {
      developer.log(
        'Sign in with Apple not supported (missing iOS capability?)',
        name: 'Apple Sign-In',
        error: e,
        stackTrace: st,
      );
      throw StateError('APPLE_AUTH_FAILED');
    }
  }

  /// [trustAuthNullImmediately]: true após apagar conta ou «Sair» — evita ecrã preto no [AppGate].
  Future<void> signOut({bool trustAuthNullImmediately = false}) async {
    if (trustAuthNullImmediately) {
      _trustAuthNullImmediately = true;
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await AuthSessionRestore.clear();
    await _auth.signOut();
  }

  /// Página de redefinição com logo (Firebase Hosting). Deploy: `firebase deploy --only hosting`
  static const passwordResetActionUrl =
      'https://facebaby-afc41.firebaseapp.com/auth/reset.html';

  /// Instruções de exclusão de conta (App Store / Google Play). Deploy: `firebase deploy --only hosting`
  static const accountDeletionInfoUrl =
      'https://facebaby-afc41.firebaseapp.com/auth/delete-account.html';

  /// Página de confirmação de e-mail (Firebase Hosting).
  static const emailVerificationActionUrl =
      'https://facebaby-afc41.firebaseapp.com/auth/verify-email.html';

  DateTime? _lastVerificationEmailSent;

  Duration? get verificationResendCooldownRemaining {
    final sent = _lastVerificationEmailSent;
    if (sent == null) return null;
    final left = EmailVerificationPolicy.resendCooldown - DateTime.now().difference(sent);
    if (left <= Duration.zero) return Duration.zero;
    return left;
  }

  /// Google/Apple: acesso imediato. E-mail/senha: exige [User.emailVerified].
  bool mustVerifyEmail(User? user) => EmailVerificationPolicy.mustVerify(user);

  ActionCodeSettings _webAuthActionSettings(String continueUrl) =>
      ActionCodeSettings(
        url: continueUrl,
        handleCodeInApp: false,
      );

  /// Confirmação de e-mail: abre o app quando instalado (oobCode no Flutter).
  ActionCodeSettings get _emailActionCodeSettings => ActionCodeSettings(
        url: emailVerificationActionUrl,
        handleCodeInApp: true,
        androidPackageName: 'com.facebaby.app',
        androidInstallApp: true,
        androidMinimumVersion: '21',
        iOSBundleId: 'com.facebaby.app',
      );

  Future<void> sendEmailVerificationToCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No signed-in user',
      );
    }
    final remaining = verificationResendCooldownRemaining;
    if (remaining != null && remaining > Duration.zero) {
      throw EmailVerificationCooldownException(remaining);
    }
    try {
      await user.sendEmailVerification(_emailActionCodeSettings);
      _lastVerificationEmailSent = DateTime.now();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        _lastVerificationEmailSent = DateTime.now();
      }
      rethrow;
    }
  }

  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed == null) return false;
    if (refreshed.emailVerified) {
      await refreshed.getIdToken(true);
    }
    return refreshed.emailVerified;
  }

  /// Perfil cloud inicial após confirmação (adiado desde o registo).
  Future<void> onEmailVerifiedBootstrap() async {
    await PremiumService.instance.markNewAccountFreeInCloud();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final e = normalizeEmail(email);
    if (e.isEmpty) throw StateError('Email inválido');
    await _auth.sendPasswordResetEmail(
      email: e,
      actionCodeSettings: _webAuthActionSettings(passwordResetActionUrl),
    );
  }

  /// Re-login recente antes de operações sensíveis (ex.: apagar conta).
  Future<void> reauthenticateWithPassword({required String password}) async {
    final user = _auth.currentUser;
    final email = user?.email?.trim();
    if (user == null || email == null || email.isEmpty) {
      throw StateError('Este acesso não suporta confirmação por palavra-passe aqui.');
    }
    final cred = EmailAuthProvider.credential(email: email, password: password.trim());
    await user.reauthenticateWithCredential(cred);
  }

  /// Google: nova credencial mesmo fluxo que o login inicial.
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sem sessão');
    }
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw StateError('Login cancelado');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await user.reauthenticateWithCredential(credential);
  }
}


