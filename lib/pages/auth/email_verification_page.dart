import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/email_verification_policy.dart';
import '../../utils/portal_time_of_day.dart';
import '../../widgets/auth_screen_background.dart';

/// Bloqueia o app até contas e-mail/senha confirmarem o e-mail.
class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key, required this.onVerified});

  final VoidCallback onVerified;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;
  Duration? _cooldownRemaining;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVerified(silent: true);
    }
  }

  Future<void> _checkVerified({bool silent = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      if (!silent) {
        _message = null;
        _messageIsError = false;
      }
    });
    try {
      final ok = await AuthService.instance.reloadAndCheckEmailVerified();
      if (!mounted) return;
      if (ok) {
        await AuthService.instance.onEmailVerifiedBootstrap();
        widget.onVerified();
        return;
      }
      if (!silent) {
        setState(() {
          _message = S.of(context).emailVerifyStillPending;
          _messageIsError = true;
        });
      }
    } catch (e) {
      if (!silent && mounted) {
        setState(() {
          _message = S.of(context).userFacingAuthError(e);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _messageIsError = false;
      _cooldownRemaining = null;
    });
    try {
      await AuthService.instance.sendEmailVerificationToCurrentUser();
      if (!mounted) return;
      setState(() {
        _message = S.of(context).emailVerifySent;
        _messageIsError = false;
        _cooldownRemaining = AuthService.instance.verificationResendCooldownRemaining;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = S.of(context).userFacingAuthError(e);
        _messageIsError = true;
        if (e is EmailVerificationCooldownException) {
          _cooldownRemaining = e.remaining;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final email = AuthService.instance.currentUser?.email?.trim() ?? '';
    final cooldown = _cooldownRemaining;
    final resendDisabled = _busy ||
        (cooldown != null && cooldown > Duration.zero);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthScreenBackground(
            asset: PortalTimeOfDay.backgroundLogin,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.mark_email_unread_outlined,
                            size: 56,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            s.emailVerifyTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.emailVerifyLead,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              height: 1.45,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              email,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Text(
                            s.emailVerifyWhy,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          if (_message != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _message!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _messageIsError
                                    ? Theme.of(context).colorScheme.error
                                    : const Color(0xFF2E7D4E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _busy ? null : () => _checkVerified(),
                            child: _busy
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(s.emailVerifyConfirmedButton),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: resendDisabled ? null : _resend,
                            child: Text(
                              cooldown != null && cooldown > Duration.zero
                                  ? s.emailVerifyResendWait(cooldown.inSeconds)
                                  : s.emailVerifyResendButton,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => AuthService.instance.signOut(
                                      trustAuthNullImmediately: true,
                                    ),
                            child: Text(s.emailVerifySignOut),
                          ),
                        ],
                      ),
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
