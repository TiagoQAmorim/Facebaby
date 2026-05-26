import 'package:flutter/material.dart';

import '../models/admin_models.dart';
import '../services/admin_auth_service.dart';
import '../services/admin_permissions.dart';
import '../services/admin_repository.dart';

class FamiliesPage extends StatelessWidget {
  const FamiliesPage({super.key});
  @override
  Widget build(BuildContext context) => _placeholder('Families', 'Browse users and open family details from the Users page.');
}

class PlansPage extends StatelessWidget {
  const PlansPage({super.key});
  @override
  Widget build(BuildContext context) => _placeholder('Plans', 'Manage premium and AI Nanny plans from user actions.');
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context) => _placeholder('Reports', 'User reports moderation — coming soon.');
}

class SuspendedUsersPage extends StatefulWidget {
  const SuspendedUsersPage({super.key});
  @override
  State<SuspendedUsersPage> createState() => _SuspendedUsersPageState();
}

class _SuspendedUsersPageState extends State<SuspendedUsersPage> {
  List<AdminUserRow> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await AdminRepository.instance.fetchUsers();
    if (mounted) {
      setState(() {
        _rows = all.where((u) => u.status == UserStatus.suspended).toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Suspended Users', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const Spacer(),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = _rows[i];
                        return ListTile(
                          title: Text(r.name),
                          subtitle: Text('${r.email} · ${planLabel(r.plan)}'),
                          trailing: AdminPermissions.canManageUsers(AdminAuthService.instance.admin)
                              ? TextButton(
                                  onPressed: () async {
                                    await AdminRepository.instance.reactivateUser(r.uid);
                                    await _load();
                                  },
                                  child: const Text('Reactivate'),
                                )
                              : null,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => _placeholder('Settings', 'Admin panel settings — coming soon.');
}

Widget _placeholder(String title, String subtitle) {
  return Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ],
    ),
  );
}
