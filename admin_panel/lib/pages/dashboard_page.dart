import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import '../models/admin_models.dart';
import '../services/admin_repository.dart';
import '../widgets/admin_layout.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await AdminRepository.instance.fetchDashboardStats();
      if (mounted) setState(() => _stats = s);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static int _crossAxisCount(double width) {
    if (width >= 1040) return 4;
    if (width >= 720) return 3;
    if (width >= 400) return 2;
    return 1;
  }

  /// Altura mínima do card (título até 2 linhas + valor + padding).
  static double _cardMainAxisExtent(int crossAxisCount) {
    return crossAxisCount <= 2 ? 124 : 116;
  }

  @override
  Widget build(BuildContext context) {
    return AdminPagePadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Dashboard',
            actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: SingleChildScrollView(
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            )
          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cols = _crossAxisCount(constraints.maxWidth);
                  final extent = _cardMainAxisExtent(cols);
                  return GridView(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: extent,
                    ),
                    children: [
                      _StatCard(title: 'Total users', value: '${_stats!.totalUsers}'),
                      _StatCard(title: 'Active users', value: '${_stats!.activeUsers}'),
                      _StatCard(title: 'Premium users', value: '${_stats!.premiumUsers}'),
                      _StatCard(title: 'Free users', value: '${_stats!.freeUsers}'),
                      _StatCard(title: 'AI Nanny users (today)', value: '${_stats!.aiNannyUsers}'),
                      _StatCard(title: 'AI calls today', value: '${_stats!.aiCallsToday}'),
                      _StatCard(
                        title: 'AI tokens today',
                        value: NumberFormat.decimalPattern().format(_stats!.aiTokensToday),
                      ),
                      _StatCard(title: 'Suspended users', value: '${_stats!.suspendedUsers}'),
                      _StatCard(title: 'New this week', value: '${_stats!.newUsersThisWeek}'),
                      _StatCard(
                        title: 'Total babies',
                        value: _stats!.totalBabies?.toString() ?? '—',
                      ),
                      _StatCard(
                        title: 'Total memories',
                        value: _stats!.totalMemories?.toString() ?? '—',
                      ),
                      _StatCard(title: 'Public memories', value: '${_stats!.totalPublicMemories}'),
                      _StatCard(
                        title: 'Weekly winner',
                        value: _stats!.weeklyWinnerName,
                        compactValue: true,
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    this.compactValue = false,
  });

  final String title;
  final String value;
  final bool compactValue;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compactValue ? 18 : 26,
                height: 1.15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
