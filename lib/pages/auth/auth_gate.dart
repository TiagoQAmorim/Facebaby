import 'dart:async' show StreamSubscription, unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../services/firebase/auth_service.dart';
import '../../services/firebase/auth_session_restore.dart';
import '../../widgets/face_baby_loading.dart';
import '../../widgets/loading_scope.dart';
import 'onboarding_page.dart';

/// Mantém a sessão após fechar o app (persistência nativa do Firebase Auth).
///
/// O primeiro `authStateChanges()` pode ser `null` **antes** do disco responder (Android).
/// Revalidamos com `currentUser` em ciclo longo (Samsung cold boot) e `signInSilently` Google.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<User?>? _idTokenSub;

  User? _user;
  bool _ready = false;
  bool _nullVerifyInFlight = false;

  void _setSignedIn(User u) {
    if (!mounted) return;
    unawaited(AuthSessionRestore.recordSignedIn(u));
    setState(() {
      _user = u;
      _ready = true;
    });
  }

  /// Depois de `authStateChanges` emitir `null`, confirma persistência antes do login.
  Future<void> _verifyStreamNullAgainstPersistence() async {
    if (_nullVerifyInFlight) return;
    _nullVerifyInFlight = true;
    try {
      final hadSession = await AuthSessionRestore.hadPriorSession();
      final maxAttempts = _restoreMaxAttempts(hadPriorSession: hadSession);
      final user = await AuthService.instance.waitForPersistedUser(
        pollInterval: const Duration(milliseconds: 100),
        maxAttempts: maxAttempts,
        onAttempt: (i) {
          if (!mounted) return;
          if (i == 0 || i % 8 != 0) return;
          unawaited(AuthService.instance.tryRestoreGoogleSession());
        },
      );
      if (!mounted) return;
      if (user != null) {
        _setSignedIn(user);
        return;
      }
      setState(() {
        _user = null;
        _ready = true;
      });
    } finally {
      _nullVerifyInFlight = false;
    }
  }

  int _restoreMaxAttempts({required bool hadPriorSession}) {
    if (kIsWeb) return hadPriorSession ? 80 : 40;
    // Samsung / Android após reiniciar o telemóvel pode demorar >10s.
    return hadPriorSession ? 200 : 80;
  }

  void _onAuthState(User? u) {
    if (!mounted) return;
    if (u != null) {
      _setSignedIn(u);
      return;
    }
    if (AuthService.instance.consumeTrustAuthNullImmediately()) {
      setState(() {
        _user = null;
        _ready = true;
      });
      return;
    }
    unawaited(_verifyStreamNullAgainstPersistence());
  }

  void _onIdToken(User? u) {
    if (!mounted) return;
    final cu = FirebaseAuth.instance.currentUser;
    if (cu == null) return;
    if (_user?.uid != cu.uid || !_ready) {
      _setSignedIn(cu);
    }
  }

  Future<void> _bootstrapSession() async {
    final initial = FirebaseAuth.instance.currentUser;
    if (initial != null) {
      _setSignedIn(initial);
      return;
    }
    await _verifyStreamNullAgainstPersistence();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    unawaited(_bootstrapSession());

    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthState);
    _idTokenSub = FirebaseAuth.instance.idTokenChanges().listen(_onIdToken);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _idTokenSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final cu = FirebaseAuth.instance.currentUser;
    if (cu != null) {
      _setSignedIn(cu);
      unawaited(AuthService.instance.tryRestoreGoogleSession());
      return;
    }
    if (_user == null && _ready) {
      unawaited(_verifyStreamNullAgainstPersistence());
    } else if (_user != null) {
      unawaited(AuthService.instance.tryRestoreGoogleSession());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: FaceBabySpinner(size: 36, strokeWidth: 3.5)),
      );
    }
    if (_user == null) {
      return const LoadingScope(child: OnboardingPage());
    }
    return widget.child;
  }
}
