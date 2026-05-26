import 'package:flutter/material.dart';

import '../services/admin_auth_service.dart';

class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 64, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Access Denied',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O painel admin é independente da conta do app.\n\n'
                    'Peça ao owner para criar em Firestore a coleção '
                    'admins_by_email com o documento do seu e-mail (minúsculas), '
                    'por exemplo tamorim9000@gmail.com, com active: true e '
                    'role: owner ou admin.\n\n'
                    'Depois entre de novo com o mesmo e-mail.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => AdminAuthService.instance.signOut(),
                    child: const Text('Sair'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
