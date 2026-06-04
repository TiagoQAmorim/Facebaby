import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../pages/dev/logged_out_screen_mirror.dart';
import '../../services/firebase/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/login_platform.dart';
import '../../utils/portal_time_of_day.dart';
import '../../widgets/auth_screen_background.dart';
import '../../widgets/language_picker.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.initialEmail,
    this.bannerMessage,
  });

  final String? initialEmail;
  final String? bannerMessage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  late String _email;
  String _password = '';
  bool _busy = false;
  String? _error;
  bool _didPrecacheBackgrounds = false;

  @override
  void initState() {
    super.initState();
    _email = widget.initialEmail?.trim() ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheBackgrounds) return;
    _didPrecacheBackgrounds = true;
    PortalTimeOfDay.precacheBackgrounds(context);
  }

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

  Future<void> _handleGoogleSignIn() async {
    await _run(() async {
      await AuthService.instance.signInWithGoogle();
      _closeAfterSuccessfulLogin();
    });
  }

  Future<void> _handleEmailSignIn() async {
    await _run(() async {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      await AuthService.instance
          .signInWithEmail(email: _email, password: _password);
      _closeAfterSuccessfulLogin();
    });
  }

  Future<void> _openNewRegistration() async {
    if (_busy) return;
    if (!mounted) return;
    Navigator.of(context).pop('restart_registration');
  }

  Future<void> _handleAppleSignIn() async {
    await _run(() async {
      await AuthService.instance.signInWithApple();
      _closeAfterSuccessfulLogin();
    });
  }

  void _closeAfterSuccessfulLogin() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _forgotPassword() async {
    final s = S.of(context);
    final initial = _email.trim();
    final ctrl = TextEditingController(text: initial);
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  'assets/onboarding/logo_welcome.png',
                  height: 72,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.child_care_rounded,
                    size: 56,
                    color: AppTheme.primaryPurple.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s.authForgotDialogTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF163B68),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.authForgotDialogBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: s.authEmailLabel,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.ctaPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(
                  s.authForgotSend,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(s.cancel),
              ),
            ],
          ),
        );
      },
    );
    if (sent != true) return;
    await _run(() async {
      await AuthService.instance.sendPasswordResetEmail(ctrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Image.asset(
                'assets/onboarding/logo.png',
                height: 28,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.mark_email_read_outlined, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(s.authResetEmailSentSnackbar)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    });
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final bgAsset = PortalTimeOfDay.backgroundLogin;
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
            borderSide:
                BorderSide(color: AppTheme.ctaPrimary.withValues(alpha: 0.8)),
          ),
        );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      backgroundColor: kAuthScreenSkyFallback,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        automaticallyImplyLeading: false,
        actions: const [LanguageButton()],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: AuthScreenBackground(
              asset: bgAsset,
              alignment: Alignment.bottomCenter,
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final kb = MediaQuery.viewInsetsOf(context).bottom;
                final h = MediaQuery.sizeOf(context).height;
                // Formulário na zona clara do céu (nuvens ficam em baixo no artwork).
                final topGap = (h * 0.08).clamp(48.0, 120.0);

                return Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 18 + kb),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: topGap),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, inner) {
                            return SingleChildScrollView(
                              clipBehavior: Clip.hardEdge,
                              physics: const ClampingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: inner.maxHeight,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 520),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Center(
                                            child: Image.asset(
                                              'assets/logo.png',
                                              height: 52,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(
                                                Icons.child_care_rounded,
                                                size: 50,
                                                color: AppTheme
                                                    .primaryPurple
                                                    .withAlpha(180),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            s.authWelcome,
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.titleLarge
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w900),
                                          ),
                                          if (widget.bannerMessage
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true) ...[
                                            const SizedBox(height: 12),
                                            Text(
                                              widget.bannerMessage!.trim(),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 14,
                                                height: 1.4,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF2E7D4E),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            initialValue: _email,
                                            decoration:
                                                fieldDeco(s.authEmailLabel),
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            autofillHints: const [
                                              AutofillHints.email
                                            ],
                                            onChanged: (v) =>
                                                _email = v.trim(),
                                            validator: (v) {
                                              final t = (v ?? '').trim();
                                              if (t.isEmpty) {
                                                return s.authValEmailRequired;
                                              }
                                              if (!t.contains('@')) {
                                                return s.authValEmailInvalid;
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            decoration: fieldDeco(
                                                s.authPasswordLabel),
                                            obscureText: true,
                                            autofillHints: const [
                                              AutofillHints.password
                                            ],
                                            onChanged: (v) => _password = v,
                                            validator: (v) {
                                              final t = (v ?? '');
                                              if (t.isEmpty) {
                                                return s
                                                    .authValPasswordRequired;
                                              }
                                              if (t.length < 6) {
                                                return s.authValPasswordMin6;
                                              }
                                              return null;
                                            },
                                          ),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : _forgotPassword,
                                              child: Text(s.authForgotPassword),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (_error != null) ...[
                                            Text(
                                              _error!,
                                              style: theme
                                                  .textTheme.bodySmall
                                                  ?.copyWith(
                                                      color: theme.colorScheme
                                                          .error),
                                            ),
                                            const SizedBox(height: 6),
                                          ],
                                          if (isIOSDevice) ...[
                                            OutlinedButton(
                                              onPressed: _busy
                                                  ? null
                                                  : _handleAppleSignIn,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.apple,
                                                      size: 22,
                                                      color: Colors
                                                          .grey.shade900),
                                                  const SizedBox(width: 10),
                                                  Text(s.authSignInApple),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                          ],
                                          OutlinedButton(
                                            onPressed: _busy
                                                ? null
                                                : _handleGoogleSignIn,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: Image.asset(
                                                    googleLogoAsset,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, __,
                                                            ___) =>
                                                        Icon(
                                                      Icons.login_rounded,
                                                      size: 20,
                                                      color: Colors
                                                          .grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(s.authSignInGoogle),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          FilledButton(
                                            onPressed: _busy
                                                ? null
                                                : _handleEmailSignIn,
                                            child: Text(_busy
                                                ? s.authSigningIn
                                                : s.authSignInEmail),
                                          ),
                                          const SizedBox(height: 6),
                                          TextButton(
                                            onPressed:
                                                _busy ? null : _openNewRegistration,
                                            child: Text(s.authCreateAccount),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (showLoggedOutScreenMirrors())
            Positioned(
              left: 8,
              bottom: MediaQuery.paddingOf(context).bottom + 8,
              child: SafeArea(
                top: false,
                child: Material(
                  color: Colors.white.withAlpha(235),
                  elevation: 3,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '[Dev] Família',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => pushLoggedOutMirrorFamily(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 0),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Família'),
                        ),
                      ],
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
