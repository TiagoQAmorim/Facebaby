import 'package:flutter/material.dart';

import '../../services/firebase/auth_service.dart';

/// Shown when [users/{uid}.status] is `suspended` (admin panel action).
class SuspendedAccountPage extends StatelessWidget {
  const SuspendedAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFCE4F3), Color(0xFFF4F7FB)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block_rounded, size: 72, color: theme.colorScheme.error),
                const SizedBox(height: 20),
                const Text(
                  'Conta suspensa',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Text(
                  'O acesso à sua conta FaceBaby foi temporariamente suspenso '
                  'por um administrador.\n\n'
                  'Se acredita que isto é um erro, contacte o suporte FaceBaby.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => AuthService.instance.signOut(),
                  child: const Text('Sair da conta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
