import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin_build_info.dart';
import '../services/admin_auth_service.dart';
import '../services/admin_sign_in_exception.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setError(Object? e) {
    if (e is AdminSignInException) {
      _error = e.message;
      return;
    }
    if (e is FirebaseAuthException) {
      _error = e.message ?? 'Erro de autenticação.';
      return;
    }
    final text = e.toString();
    if (text.contains('Login cancelado')) {
      _error = 'Login cancelado.';
      return;
    }
    if (text.contains('Null check operator')) {
      _error =
          'Erro interno no login. Abra o console do browser (F12) e confira os logs AdminAuth.';
      return;
    }
    _error = text;
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        setState(() => _setError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayError = _error ?? AdminAuthService.instance.error;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F4FC), Color(0xFFFCE4F3), Color(0xFFF4F7FB)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        package: 'facebaby_admin',
                        height: 72,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'FaceBaby Admin',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Painel administrativo seguro',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      if (displayError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          displayError,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() => AdminAuthService.instance.signInEmail(
                                    _email.text,
                                    _password.text,
                                  )),
                          child: Text(_busy ? 'Entrando…' : 'Login'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(AdminAuthService.instance.signInGoogle),
                        icon: Image.asset(
                          'assets/google_g_logo.png',
                          package: 'facebaby_admin',
                          height: 20,
                        ),
                        label: const Text('Entrar com Google'),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Acesso restrito aos administradores FaceBaby',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        kAdminBuildLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
