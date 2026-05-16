import 'dart:async' show StreamSubscription, unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
      for (var k = 0; k < 35; k++) {
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
    }

    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthState);
    _idTokenSub = FirebaseAuth.instance.idTokenChanges().listen(_onIdToken);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cu = FirebaseAuth.instance.currentUser;
      if (cu != null) _setSignedIn(cu);
    });
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
    if (cu != null) _setSignedIn(cu);
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
