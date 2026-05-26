import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/admin_models.dart';
import '../services/admin_repository.dart';
import '../widgets/admin_layout.dart';

class FamilyDetailsPage extends StatefulWidget {
  const FamilyDetailsPage({super.key, required this.uid});

  final String uid;

  @override
  State<FamilyDetailsPage> createState() => _FamilyDetailsPageState();
}

class _FamilyDetailsPageState extends State<FamilyDetailsPage> {
  FamilyDetails? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _data = await AdminRepository.instance.fetchFamily(widget.uid);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final d = _data!;
    final p = d.profile;
    final fmt = DateFormat('dd/MM/yyyy');
    final baby = d.babies.isNotEmpty ? d.babies.first : null;

    return SingleChildScrollView(
      padding: AdminLayout.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(onPressed: () => context.go('/users'), icon: const Icon(Icons.arrow_back)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Family Details', style: AdminLayout.pageTitleStyle(context)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _section('Account', [
                _line('Owner', (p['name'] as String?) ?? '—'),
                _line('Email', (p['email'] as String?) ?? '—'),
                _line('Plan', planLabel(planFromData(p))),
                _line('Status', statusFromData(p).name),
                _line('Created', _fmt(p['createdAt'], fmt)),
                _line('Last login', _fmt(p['lastLoginAt'] ?? p['last_login_at'], fmt)),
              ]),
              _section('Mother profile', [
                _line('Name', (p['name'] as String?) ?? '—'),
                _line('Phone', (p['phone'] as String?) ?? '—'),
                _line('Height', '${p['height_cm'] ?? '—'} cm'),
                _line('Birth', (p['birth_date'] as String?) ?? '—'),
              ]),
              _section('Father profile', [
                _line('Name', (p['father_name'] as String?) ?? '—'),
                _line('Height', '${p['father_height_cm'] ?? '—'} cm'),
                _line('Birth', (p['father_birth_date'] as String?) ?? '—'),
              ]),
              if (baby != null)
                _section('Baby profile', [
                  _line('Name', (baby['name'] as String?) ?? '—'),
                  _line('Birth', (baby['birth_date'] as String?) ?? '—'),
                  _line('Gender', (baby['sex'] as String?) ?? '—'),
                  _line('Weight', '${baby['weight_kg'] ?? '—'} kg'),
                  _line('Height', '${baby['height_cm'] ?? '—'} cm'),
                  _line('Zodiac', (baby['zodiac_sign'] as String?) ?? '—'),
                ]),
              _section('Stats', [
                _line('Total memories', '${d.memoriesCount}'),
                _line('Total reports', '${d.reportsCount}'),
                _line('Public memories', '${d.publicMemoriesCount}'),
                _line('Weekly submissions', '${d.weeklySubmissions}'),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic v, DateFormat fmt) {
    final dt = tsToDate(v);
    return dt == null ? '—' : fmt.format(dt);
  }

  Widget _section(String title, List<Widget> lines) {
    return SizedBox(
      width: 320,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 12),
              ...lines,
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700))),
            Expanded(child: Text(v)),
          ],
        ),
      );
}
