import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/admin_auth_service.dart';
import '../services/admin_permissions.dart';
import '../theme/admin_theme.dart';
import 'admin_layout.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  static const _items = [
    ('/', 'Dashboard', Icons.dashboard_rounded),
    ('/users', 'Users', Icons.people_rounded),
    ('/weekly-photo', 'Weekly Photo', Icons.emoji_events_rounded),
    ('/weekly-photo-reports', 'Denuncias', Icons.report_rounded),
    ('/public-memories', 'Public Memories', Icons.photo_library_rounded),
    ('/audit-logs', 'Audit Logs', Icons.history_rounded),
    ('/messaging', 'Mensageria', Icons.chat_bubble_rounded),
  ];

  static String titleForPath(String path) {
    if (path.startsWith('/users/')) return 'Family';
    for (final (route, label, _) in _items) {
      if (path == route) return label;
      if (route == '/users' && path.startsWith('/users')) return label;
    }
    return 'FaceBaby Admin';
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final wide = AdminLayout.isWide(context);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 260,
              child: _AdminSidePanel(
                path: path,
                onNavigate: (route) => context.go(route),
                onLogout: () => _logout(context),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFFF4F7FB),
                child: child,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text(titleForPath(path)),
        backgroundColor: AdminTheme.purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: Drawer(
        width: 300,
        child: _AdminSidePanel(
          path: path,
          onNavigate: (route) {
            Navigator.pop(context);
            context.go(route);
          },
          onLogout: () {
            Navigator.pop(context);
            _logout(context);
          },
        ),
      ),
      body: child,
    );
  }

  static Future<void> _logout(BuildContext context) async {
    await AdminAuthService.instance.signOut();
    if (context.mounted) context.go('/login');
  }
}

class _AdminSidePanel extends StatelessWidget {
  const _AdminSidePanel({
    required this.path,
    required this.onNavigate,
    required this.onLogout,
  });

  final String path;
  final void Function(String route) onNavigate;
  final VoidCallback onLogout;

  static LinearGradient get _gradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AdminTheme.purple.withValues(alpha: 0.92),
          AdminTheme.pink.withValues(alpha: 0.88),
        ],
      );

  bool _isSelected(String route) =>
      path == route || (route == '/users' && path.startsWith('/users'));

  @override
  Widget build(BuildContext context) {
    final profile = AdminAuthService.instance.admin;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: _gradient),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Image.asset('assets/logo.png', height: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FaceBaby Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        if (profile != null)
                          Text(
                            roleLabel(profile.role),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final (route, label, icon) in AdminShell._items)
                    ListTile(
                      leading: Icon(icon, color: Colors.white),
                      title: Text(
                        label,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: _isSelected(route) ? 1 : 0.85,
                          ),
                          fontWeight:
                              _isSelected(route) ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                      selected: _isSelected(route),
                      selectedTileColor: Colors.white.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () => onNavigate(route),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.white70),
              title: const Text('Logout', style: TextStyle(color: Colors.white70)),
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}
