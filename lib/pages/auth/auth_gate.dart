import 'dart:async' show StreamSubscription, unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firebase/auth_service.dart';
import '../../widgets/face_baby_loading.dart';
import '../../widgets/loading_scope.dart';
import 'onboarding_page.dart';

/// Mantém a sessão após fechar o app (persistência nativa do Firebase Auth).
///
/// O primeiro `authStateChanges()` pode ser `null` **antes** do disco responder (Android).
/// Revalidamos com `currentUser` em ciclo curto (uma vez por “null” no stream) e com
/// `idTokenChanges()` (o SDK muitas vezes restaua a sessão aí sem novo `authState`).
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
    setState(() {
      _user = u;
      _ready = true;
    });
  }

  /// Depois de `authStateChanges` emitir `null`, confirma com `currentUser` (persistência).
  Future<void> _verifyStreamNullAgainstPersistence() async {
    if (_nullVerifyInFlight) return;
    _nullVerifyInFlight = true;
    try {
      // Android pode demorar alguns segundos a ler a sessão do disco após cold start.
      for (var k = 0; k < 60; k++) {
        if (k > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        if (!mounted) return;
        final cu = FirebaseAuth.instance.currentUser;
        if (cu != null) {
          _setSignedIn(cu);
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _user = null;
        _ready = true;
      });
    } finally {
      _nullVerifyInFlight = false;
    }
  }

  void _onAuthState(User? u) {
    if (!mounted) return;
    if (u != null) {
      _setSignedIn(u);
      return;
    }
    // Só confiar em null imediato após logout explícito — nunca só porque
    // `currentUser` ainda é null enquanto o SDK restaura a sessão do disco.
    if (AuthService.instance.consumeTrustAuthNullImmediately()) {
      setState(() {
        _user = null;
        _ready = true;
      });
      return;
    }
    unawaited(_verifyStreamNullAgainstPersistence());
  }

  void _onIdToken(User? _) {
    if (!mounted) return;
    final cu = FirebaseAuth.instance.currentUser;
    if (cu == null) return;
    if (_user?.uid != cu.uid || !_ready) {
      _setSignedIn(cu);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final initial = FirebaseAuth.instance.currentUser;
    if (initial != null) {
      _user = initial;
      _ready = true;
    } else {
      unawaited(_verifyStreamNullAgainstPersistence());
    }

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
      return;
    }
    if (_user == null && _ready) {
      unawaited(_verifyStreamNullAgainstPersistence());
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
