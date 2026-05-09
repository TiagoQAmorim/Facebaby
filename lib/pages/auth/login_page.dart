import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../services/firebase/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/language_picker.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
    } catch (e) {
      setState(() => _error = S.of(context).userFacingAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final s = S.of(context);
    final initial = _email.trim();
    final ctrl = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(s.authForgotDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.authForgotDialogBody),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: s.authEmailLabel),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.authForgotSend)),
          ],
        );
      },
    );
    if (ok != true) return;
    await _run(() async {
      await AuthService.instance.sendPasswordResetEmail(ctrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.authResetEmailSentSnackbar)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    const bgAsset = 'assets/auth/login_background.png';
    const googleLogoAsset = 'assets/google_g_logo.png';
    InputDecoration fieldDeco(String label) => InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.ctaPrimary.withValues(alpha: 0.8)),
          ),
        );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(s.authLoginTitle),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        actions: const [LanguageButton()],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              bgAsset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => ColoredBox(color: AppTheme.background),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        Center(
                          child: Image.asset(
                            'assets/logo.png',
                            height: 72,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.child_care_rounded,
                              size: 56,
                              color: AppTheme.primaryPurple.withAlpha(180),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          s.authWelcome,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: fieldDeco(s.authEmailLabel),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          onChanged: (v) => _email = v.trim(),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return s.authValEmailRequired;
                            if (!t.contains('@')) return s.authValEmailInvalid;
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          decoration: fieldDeco(s.authPasswordLabel),
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          onChanged: (v) => _password = v,
                          validator: (v) {
                            final t = (v ?? '');
                            if (t.isEmpty) return s.authValPasswordRequired;
                            if (t.length < 6) return s.authValPasswordMin6;
                            return null;
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _busy ? null : _forgotPassword,
                            child: Text(s.authForgotPassword),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                          ),
                          const SizedBox(height: 8),
                        ],
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                    if (!(_formKey.currentState?.validate() ?? false)) return;
                                    await AuthService.instance.signInWithEmail(email: _email, password: _password);
                                  }),
                          child: Text(_busy ? s.authSigningIn : s.authSignIn),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                    await AuthService.instance.signInWithGoogle();
                                  }),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Image.asset(
                                  googleLogoAsset,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.login_rounded,
                                    size: 20,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(s.authSignInGoogle),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                                  );
                                },
                          child: Text(s.authCreateAccount),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

