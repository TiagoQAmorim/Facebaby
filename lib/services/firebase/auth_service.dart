import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_sign_in_helpers.dart';

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
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw StateError('Login cancelado');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
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


