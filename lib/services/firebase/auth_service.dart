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

  FirebaseAuth get _auth => FirebaseAuth.instance;

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const <String>[
      'email',
      'profile',
      'openid',
    ],
    serverClientId: hasGoogleWebClientId ? kGoogleWebClientId : null,
  );

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      await cred.user?.updateDisplayName(name);
      await cred.user?.reload();
    }
    return cred;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
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
      return await _auth.signInWithCredential(credential);
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

      return await _auth.signInWithCredential(oauthCredential);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw StateError('Login cancelado');
      }
      throw StateError('APPLE_AUTH_FAILED');
    } on SignInWithAppleNotSupportedException {
      throw StateError('APPLE_AUTH_FAILED');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final e = email.trim();
    if (e.isEmpty) throw StateError('Email inválido');
    await _auth.sendPasswordResetEmail(email: e);
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


