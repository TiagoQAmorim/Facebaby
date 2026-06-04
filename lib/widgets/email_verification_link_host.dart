import 'dart:async' show StreamSubscription, unawaited;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/firebase/auth_service.dart';
import '../services/firebase/email_verification_deep_link.dart';

/// Escuta links de confirmação de e-mail e aplica o código no Firebase Auth do app.
class EmailVerificationLinkHost extends StatefulWidget {
  const EmailVerificationLinkHost({super.key, required this.child});

  final Widget child;

  @override
  State<EmailVerificationLinkHost> createState() =>
      _EmailVerificationLinkHostState();
}

class _EmailVerificationLinkHostState extends State<EmailVerificationLinkHost> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      unawaited(_listenAppLinks());
    }
  }

  Future<void> _listenAppLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _handleUri(initial);
      _linkSub = _appLinks.uriLinkStream.listen(_handleUri);
    } catch (e, st) {
      debugPrint('EmailVerificationLinkHost: $e\n$st');
    }
  }

  Future<void> _handleUri(Uri uri) async {
    try {
      final result = await EmailVerificationDeepLink.tryApply(uri);
      if (result == EmailVerificationLinkResult.notApplicable) return;
      await AuthService.instance.reloadAndCheckEmailVerified();
      if (result == EmailVerificationLinkResult.applied ||
          result == EmailVerificationLinkResult.alreadyVerified) {
        await AuthService.instance.onEmailVerifiedBootstrap();
      }
    } catch (e, st) {
      debugPrint('EmailVerificationLinkHost.handle: $e\n$st');
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
