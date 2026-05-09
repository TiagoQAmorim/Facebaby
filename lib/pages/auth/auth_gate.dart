import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/face_baby_loading.dart';
import '../../widgets/loading_scope.dart';
import '../../services/firebase/auth_service.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: FaceBabySpinner(size: 36, strokeWidth: 3.5)),
          );
        }
        final user = snap.data;
        if (user == null) {
          return const LoadingScope(child: LoginPage());
        }
        return child;
      },
    );
  }
}

