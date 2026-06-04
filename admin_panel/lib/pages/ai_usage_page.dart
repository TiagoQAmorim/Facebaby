import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/admin_models.dart';
import '../services/admin_repository.dart';
import '../widgets/admin_layout.dart';
import '../widgets/admin_table_viewport.dart';

class AiUsagePage extends StatefulWidget {
  const AiUsagePage({super.key});

  @override
  State<AiUsagePage> createState() => _AiUsagePageState();
}

class _AiUsagePageState extends State<AiUsagePage> {
  AiUsageStats? _stats;
  bool _loading = true;
  String? _error;
  late String _dateKey;

  @override
  void initState() {
    super.initState();
    _dateKey = DateFormat('yyyyMMdd').format(DateTime.now());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await AdminRepository.instance.fetchAiUsageStats(
        dateKey: _dateKey,
      );
      if (mounted) setState(() => _stats = stats);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final parsed = DateTime.tryParse(
      '${_dateKey.substring(0, 4)}-${_dateKey.substring(4, 6)}-${_dateKey.substring(6, 8)}',
    );
    final initial = parsed ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() => _dateKey = DateFormat('yyyyMMdd').format(picked));
    await _load();
  }

  String _formatDateKey(String key) {
    if (key.length != 8) return key;
    return '${key.substring(6, 8)}/${key.substring(4, 6)}/${key.substring(0, 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return AdminPagePadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Uso de IA',
            actions: [
              OutlinedButton.icon(
                onPressed: _loading ? null : _pickDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(_formatDateKey(_dateKey)),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            )
          else if (_stats != null)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _SummaryChip(
                              label: 'Chamadas',
                              value: '${_stats!.totalCalls}',
                            ),
                            _SummaryChip(
                              label: 'Tokens',
                              value: NumberFormat.decimalPattern().format(
                                _stats!.totalTokens,
                              ),
                            ),
                            _SummaryChip(
                              label: 'Utilizadores activos',
                              value: '${_stats!.activeUsers}',
                            ),
                            if (_stats!.totalWhisperSeconds > 0)
                              _SummaryChip(
                                label: 'Whisper (s)',
                                value: '${_stats!.totalWhisperSeconds}',
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _FeatureTable(rows: _stats!.byFeature)),
                              const SizedBox(width: 16),
                              Expanded(child: _TopUsersTable(rows: _stats!.topUsers)),
                            ],
                          )
                        else ...[
                          _FeatureTable(rows: _stats!.byFeature),
                          const SizedBox(height: 24),
                          _TopUsersTable(rows: _stats!.topUsers),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTable extends StatelessWidget {
  const _FeatureTable({required this.rows});

  final List<AiUsageFeatureRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Por ferramenta',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            AdminTableViewport(
              minScrollWidth: 520,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Ferramenta')),
                  DataColumn(label: Text('Chamadas'), numeric: true),
                  DataColumn(label: Text('Tokens'), numeric: true),
                ],
                rows: rows.isEmpty
                    ? [
                        const DataRow(
                          cells: [
                            DataCell(Text('Sem dados neste dia')),
                            DataCell(Text('')),
                            DataCell(Text('')),
                          ],
                        ),
                      ]
                    : rows
                        .map(
                          (r) => DataRow(
                            cells: [
                              DataCell(Text(r.label)),
                              DataCell(Text('${r.calls}')),
                              DataCell(
                                Text(NumberFormat.decimalPattern().format(r.totalTokens)),
                              ),
                            ],
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopUsersTable extends StatelessWidget {
  const _TopUsersTable({required this.rows});

  final List<AiUsageTopUserRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top utilizadores (tokens)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            AdminTableViewport(
              minScrollWidth: 620,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Utilizador')),
                  DataColumn(label: Text('Tokens'), numeric: true),
                  DataColumn(label: Text('Principal')),
                ],
                rows: rows.isEmpty
                    ? [
                        const DataRow(
                          cells: [
                            DataCell(Text('—')),
                            DataCell(Text('Sem dados neste dia')),
                            DataCell(Text('')),
                            DataCell(Text('')),
                          ],
                        ),
                      ]
                    : rows
                        .map(
                          (r) => DataRow(
                            cells: [
                              DataCell(Text('${r.rank}')),
                              DataCell(
                                InkWell(
                                  onTap: () => context.go('/users/${r.uid}'),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        r.email.isEmpty ? r.uid : r.email,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(NumberFormat.decimalPattern().format(r.totalTokens)),
                              ),
                              DataCell(Text(r.topFeatureLabel)),
                            ],
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
