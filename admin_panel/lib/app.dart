import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/ai_usage_page.dart';
import 'pages/audit_logs_page.dart';
import 'pages/access_denied_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/family_details_page.dart';
import 'pages/login_page.dart' show AdminLoginPage;
import 'pages/messaging_page.dart';
import 'pages/public_memories_page.dart';
import 'pages/users_page.dart';
import 'pages/weekly_photo_page.dart';
import 'pages/weekly_photo_reports_page.dart';
import 'services/admin_auth_service.dart';
import 'theme/admin_scroll_behavior.dart';
import 'theme/admin_theme.dart';
import 'widgets/admin_shell.dart';

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final GoRouter _router = GoRouter(
    refreshListenable: AdminAuthService.instance,
    initialLocation: '/login',
    redirect: (context, state) {
      final auth = AdminAuthService.instance;
      final onLogin = state.matchedLocation == '/login';
      final onDenied = state.matchedLocation == '/access-denied';

      if (!auth.ready) return null;
      if (!auth.isLoggedIn) return onLogin ? null : '/login';
      if (!auth.isAdmin) return onDenied ? null : '/access-denied';
      if (onLogin || onDenied) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const AdminLoginPage()),
      GoRoute(path: '/access-denied', builder: (_, __) => const AccessDeniedPage()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardPage()),
          GoRoute(path: '/users', builder: (_, __) => const UsersPage()),
          GoRoute(path: '/ai-usage', builder: (_, __) => const AiUsagePage()),
          GoRoute(
            path: '/users/:uid',
            builder: (_, state) {
              final uid = state.pathParameters['uid'] ?? '';
              if (uid.isEmpty) {
                return const Scaffold(
                  body: Center(child: Text('Invalid user id')),
                );
              }
              return FamilyDetailsPage(uid: uid);
            },
          ),
          GoRoute(path: '/weekly-photo', builder: (_, __) => const WeeklyPhotoPage()),
          GoRoute(
            path: '/weekly-photo-reports',
            builder: (_, __) => const WeeklyPhotoReportsPage(),
          ),
          GoRoute(path: '/public-memories', builder: (_, __) => const PublicMemoriesPage()),
          GoRoute(path: '/audit-logs', builder: (_, __) => const AuditLogsPage()),
          GoRoute(path: '/messaging', builder: (_, __) => const MessagingPage()),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FaceBaby Admin',
      theme: AdminTheme.light(),
      scrollBehavior: const AdminScrollBehavior(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
