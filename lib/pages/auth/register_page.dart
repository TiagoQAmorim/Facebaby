import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../services/firebase/auth_service.dart';
import '../../widgets/card_box.dart';
import '../../widgets/language_picker.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
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
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = S.of(context).userFacingAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.authRegisterAppBarTitle),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CardBox(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(s.authRegisterTitle, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: InputDecoration(labelText: s.authRegisterNameLabel),
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        onChanged: (v) => _name = v.trim(),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return s.authValNameRequired;
                          if (t.length < 2) return s.authValNameShort;
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: InputDecoration(labelText: s.authEmailLabel),
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
                        decoration: InputDecoration(labelText: s.authRegisterPasswordLabel),
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        onChanged: (v) => _password = v,
                        validator: (v) {
                          final t = (v ?? '');
                          if (t.isEmpty) return s.authValPasswordRequired;
                          if (t.length < 6) return s.authValPasswordMin6;
                          return null;
                        },
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
                                  await AuthService.instance.registerWithEmail(
                                    email: _email,
                                    password: _password,
                                    displayName: _name,
                                  );
                                }),
                        child: Text(_busy ? s.authRegisterCreating : s.authRegisterSubmit),
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
