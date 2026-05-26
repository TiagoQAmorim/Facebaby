import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'admin_audit_service.dart';
import 'admin_permissions.dart';
import 'admin_sign_in_exception.dart';

/// OAuth Web client ID (opcional). `--dart-define=GOOGLE_WEB_CLIENT_ID=...`
const String _kGoogleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

bool get _hasGoogleWebClientId =>
    _kGoogleWebClientId.isNotEmpty &&
    _kGoogleWebClientId.contains('.apps.googleusercontent.com');

class AdminProfile {
  const AdminProfile({
    required this.uid,
    required this.email,
    required this.role,
  });

  final String uid;
  final String email;
  final AdminRole role;
}

class AdminAuthService extends ChangeNotifier {
  AdminAuthService._();
  static final AdminAuthService instance = AdminAuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _functions =
      FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  GoogleSignIn? _googleSignIn;

  GoogleSignIn _mobileGoogleSignIn() {
    final existing = _googleSignIn;
    if (existing != null) return existing;
    final created = GoogleSignIn(
      scopes: const ['email', 'openid', 'profile'],
      serverClientId: _hasGoogleWebClientId ? _kGoogleWebClientId : null,
    );
    _googleSignIn = created;
    return created;
  }

  User? get user => _auth.currentUser;
  AdminProfile? _admin;
  bool _checking = false;
  String? _error;

  AdminProfile? get admin => _admin;
  bool get isLoggedIn => _auth.currentUser != null;
  bool get hasPanelAccess => AdminPermissions.hasPanelAccess(_admin);
  bool get isAdmin => hasPanelAccess;
  bool get canManageUsers => hasPanelAccess;
  bool get checking => _checking;
  bool _ready = false;
  bool get ready => _ready;
  String? get error => _error;
  bool _signInInProgress = false;

  Future<void> init() async {
    _auth.authStateChanges().listen((_) async {
      if (_signInInProgress) return;
      await refreshAdminClaim();
      notifyListeners();
    });
    await refreshAdminClaim();
    _ready = true;
    notifyListeners();
  }

  Future<void> refreshAdminClaim() async {
    final current = _auth.currentUser;
    if (current == null) {
      _admin = null;
      return;
    }
    _checking = true;
    try {
      _admin = await _loadAdminProfileFromFirestore(current);
    } catch (e, st) {
      debugPrint('AdminAuth refreshAdminClaim error: $e\n$st');
      _admin = null;
    } finally {
      _checking = false;
    }
  }

  /// Validação Firestore partilhada após email ou Google (sem `!`).
  Future<void> validateAdminAccessAfterLogin({UserCredential? credential}) async {
    final user = credential?.user ?? _auth.currentUser;
    debugPrint('AdminAuth: validateAdminAccessAfterLogin start');
    debugPrint('AdminAuth: credential.user=${credential?.user?.uid}');
    debugPrint('AdminAuth: currentUser=${_auth.currentUser?.uid}');

    if (user == null) {
      debugPrint('AdminAuth: user is null after auth');
      await _signOutSilently();
      throw const AdminSignInException('Falha ao autenticar usuário.');
    }

    final uid = user.uid;
    if (uid.isEmpty) {
      await _signOutSilently();
      throw const AdminSignInException('Falha ao autenticar usuário.');
    }

    final profile = await _resolveAdminProfile(user);
    if (profile == null) {
      await _signOutSilently();
      _error = 'Acesso negado. O painel admin usa allowlist por e-mail '
          '(admins_by_email), independente da conta do app.';
      throw const AdminSignInException('Acesso negado.');
    }

    _admin = profile;
    _error = null;
    debugPrint('AdminAuth: access granted role=${roleLabel(profile.role)}');
  }

  /// Liga [admins/{uid}] ao e-mail allowlisted — sobrevive a apagar/recriar conta do app.
  Future<void> _linkAdminSessionDoc({
    required String uid,
    required String emailKey,
    required AdminRole role,
  }) async {
    await _db.collection('admins').doc(uid).set({
      'email': emailKey,
      'role': roleLabel(role),
      'active': true,
      'linkedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  AdminProfile? _profileFromAdminData(
    String uid,
    String emailKey,
    Map<String, dynamic> data,
  ) {
    if (data['active'] != true) return null;
    final role = parseAdminRole(data['role'] as String?);
    if (role == null) return null;
    final storedEmail = (data['email'] as String?)?.trim();
    return AdminProfile(
      uid: uid,
      email: storedEmail != null && storedEmail.isNotEmpty ? storedEmail : emailKey,
      role: role,
    );
  }

  Future<AdminProfile?> _ensureAdminViaCallable(String uid, String emailKey) async {
    try {
      final result =
          await _functions.httpsCallable('ensureAdminPanelAccess').call();
      final data = Map<String, dynamic>.from(result.data as Map);
      debugPrint('AdminAuth: ensureAdminPanelAccess $data');
      if (data['ok'] != true) return null;
      final role = parseAdminRole(data['role'] as String?);
      if (role == null) return null;
      return AdminProfile(uid: uid, email: emailKey, role: role);
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'AdminAuth: ensureAdminPanelAccess ${e.code} ${e.message}',
      );
      if (e.code == 'permission-denied' ||
          e.code == 'failed-precondition' ||
          e.code == 'unauthenticated') {
        return null;
      }
      return null;
    } catch (e, st) {
      debugPrint('AdminAuth: ensureAdminPanelAccess failed: $e\n$st');
      return null;
    }
  }

  Future<AdminProfile?> _resolveAdminProfile(User user) async {
    final uid = user.uid;
    final emailKey = (user.email ?? '').trim().toLowerCase();
    debugPrint('AdminAuth: resolve uid=$uid email=$emailKey');
    if (emailKey.isEmpty) return null;

    final fromCallable = await _ensureAdminViaCallable(uid, emailKey);
    if (fromCallable != null) return fromCallable;

    final direct = await _db.collection('admins').doc(uid).get();
    if (direct.exists && direct.data() != null) {
      final p = _profileFromAdminData(uid, emailKey, direct.data()!);
      if (p != null) return p;
    }

    final listed = await _db.collection('admins_by_email').doc(emailKey).get();
    debugPrint('AdminAuth: admins_by_email exists=${listed.exists}');
    if (listed.exists && listed.data() != null) {
      final listData = listed.data()!;
      if (listData['active'] == true) {
        final role = parseAdminRole(listData['role'] as String?);
        if (role != null) {
          try {
            await _linkAdminSessionDoc(uid: uid, emailKey: emailKey, role: role);
          } catch (e, st) {
            debugPrint('AdminAuth: link admins/$uid failed: $e\n$st');
            return null;
          }
          return AdminProfile(uid: uid, email: emailKey, role: role);
        }
      }
    }

    try {
      final legacy = await _db
          .collection('admins')
          .where('email', isEqualTo: emailKey)
          .limit(1)
          .get();
      if (legacy.docs.isNotEmpty) {
        debugPrint(
          'AdminAuth: found legacy admins/${legacy.docs.first.id} — '
          'create admins_by_email/$emailKey in Firestore to login after app account deletion.',
        );
      }
    } catch (e, st) {
      debugPrint('AdminAuth: legacy admins email query failed: $e\n$st');
    }

    return null;
  }

  Future<AdminProfile?> _loadAdminProfileFromFirestore(User user) async {
    return _resolveAdminProfile(user);
  }

  Future<void> _signOutSilently() async {
    if (!kIsWeb) {
      try {
        await _mobileGoogleSignIn().signOut();
      } catch (e) {
        debugPrint('AdminAuth: google signOut skipped: $e');
      }
    }
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('AdminAuth: firebase signOut: $e');
    }
    _admin = null;
  }

  Future<void> _logAdminLogin(String method) async {
    try {
      await AdminAuditService.instance.log(
        action: AdminAuditAction.adminLogin,
        details: method,
      );
    } catch (e, st) {
      debugPrint('AdminAuth: audit log failed (non-fatal): $e\n$st');
    }
  }

  Future<UserCredential> _signInWithGoogleFirebase() async {
    if (kIsWeb) {
      debugPrint('AdminAuth: signInWithPopup (web)');
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.setCustomParameters({'prompt': 'select_account'});
      try {
        return await _auth.signInWithPopup(provider);
      } on FirebaseAuthException catch (e) {
        debugPrint('AdminAuth: popup FirebaseAuthException ${e.code} ${e.message}');
        if (e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request') {
          throw const AdminSignInException('Login cancelado.');
        }
        rethrow;
      }
    }

    debugPrint('AdminAuth: GoogleSignIn (non-web)');
    final GoogleSignInAccount? account = await _mobileGoogleSignIn().signIn();
    if (account == null) {
      throw const AdminSignInException('Login cancelado.');
    }

    final GoogleSignInAuthentication googleAuth = await account.authentication;
    final String? idToken = googleAuth.idToken;
    final String? accessToken = googleAuth.accessToken;
    debugPrint('AdminAuth: idToken present=${idToken != null} accessToken present=${accessToken != null}');

    if (idToken == null && accessToken == null) {
      throw const AdminSignInException(
        'Não foi possível obter credenciais do Google. '
        'Ative o provedor Google no Firebase Auth e configure o OAuth Web.',
      );
    }

    return _auth.signInWithCredential(
      GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      ),
    );
  }

  Future<void> signInEmail(String email, String password) async {
    _error = null;
    _signInInProgress = true;
    try {
      debugPrint('AdminAuth: signInEmail start');
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await validateAdminAccessAfterLogin(credential: cred);
      await _logAdminLogin('email');
      notifyListeners();
    } on AdminSignInException {
      notifyListeners();
      rethrow;
    } on FirebaseAuthException catch (e, st) {
      debugPrint('AdminAuth: signInEmail FirebaseAuthException ${e.code}\n$st');
      await _signOutSilently();
      _error = e.message ?? 'Erro de autenticação.';
      notifyListeners();
      rethrow;
    } catch (e, st) {
      debugPrint('AdminAuth: signInEmail unexpected $e\n$st');
      await _signOutSilently();
      _error = 'Erro ao entrar. Tente novamente.';
      notifyListeners();
      throw AdminSignInException(_error ?? 'Erro ao entrar.');
    } finally {
      _signInInProgress = false;
    }
  }

  Future<void> signInGoogle() async {
    _error = null;
    _signInInProgress = true;
    try {
      debugPrint('AdminAuth: signInGoogle start kIsWeb=$kIsWeb');
      final cred = await _signInWithGoogleFirebase();
      await validateAdminAccessAfterLogin(credential: cred);
      await _logAdminLogin('google');
      notifyListeners();
    } on AdminSignInException {
      notifyListeners();
      rethrow;
    } on FirebaseAuthException catch (e, st) {
      debugPrint('AdminAuth: signInGoogle FirebaseAuthException ${e.code}\n$st');
      await _signOutSilently();
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        throw const AdminSignInException('Login cancelado.');
      }
      _error = e.message ?? 'Erro de autenticação com Google.';
      notifyListeners();
      rethrow;
    } catch (e, st) {
      debugPrint('AdminAuth: signInGoogle unexpected $e\n$st');
      await _signOutSilently();
      final msg = e is AdminSignInException
          ? e.message
          : (e.toString().contains('Null check')
              ? 'Erro interno no login Google. Verifique o console (F12) e as regras Firestore admins/{uid}.'
              : 'Erro ao entrar com Google.');
      _error = msg;
      notifyListeners();
      throw AdminSignInException(msg);
    } finally {
      _signInInProgress = false;
    }
  }

  Future<void> signOut() async {
    await _signOutSilently();
    notifyListeners();
  }

  void setError(String? msg) {
    _error = msg;
    notifyListeners();
  }
}
