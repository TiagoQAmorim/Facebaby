import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/admin_models.dart';
import '../services/admin_repository.dart';
import '../widgets/admin_layout.dart';
import '../widgets/admin_storage_image.dart';
import '../widgets/confirm_dialog.dart';

class WeeklyPhotoReportsPage extends StatefulWidget {
  const WeeklyPhotoReportsPage({super.key});

  @override
  State<WeeklyPhotoReportsPage> createState() => _WeeklyPhotoReportsPageState();
}

class _WeeklyPhotoReportsPageState extends State<WeeklyPhotoReportsPage> {
  List<WeeklyPhotoReportRow> _rows = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'open';

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
      _rows = await AdminRepository.instance.fetchWeeklyPhotoReports();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<WeeklyPhotoReportRow> get _filtered {
    if (_statusFilter == 'all') return _rows;
    return _rows.where((r) => r.status == _statusFilter).toList();
  }

  Future<void> _markReviewed(WeeklyPhotoReportRow row) async {
    try {
      await AdminRepository.instance.markWeeklyPhotoReportReviewed(row.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _hideMemory(WeeklyPhotoReportRow row) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hide public memory?',
      message:
          'This will hide the photo from the public gallery and mark the report as reviewed.',
      confirmLabel: 'Hide',
      destructive: true,
    );
    if (ok != true || !mounted) return;
    try {
      await AdminRepository.instance.hidePublicMemoryFromReport(
        reportId: row.id,
        publicMemoryId: row.publicMemoryId,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memory hidden and report reviewed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final filtered = _filtered;
    final openCount = _rows.where((r) => r.isOpen).length;

    return AdminPagePadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: 'Denuncias',
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$openCount open report(s)',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Open'),
                selected: _statusFilter == 'open',
                onSelected: (_) => setState(() => _statusFilter = 'open'),
              ),
              ChoiceChip(
                label: const Text('Reviewed'),
                selected: _statusFilter == 'reviewed',
                onSelected: (_) => setState(() => _statusFilter = 'reviewed'),
              ),
              ChoiceChip(
                label: const Text('All'),
                selected: _statusFilter == 'all',
                onSelected: (_) => setState(() => _statusFilter = 'all'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else if (filtered.isEmpty)
            const Expanded(
              child: Center(child: Text('No reports in this filter.')),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final row = filtered[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (row.photoUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: AdminStorageImage(
                                    httpsUrl: row.photoUrl,
                                    publicMemoryDocId: row.publicMemoryId,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Container(
                                  width: 72,
                                  height: 72,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.image_not_supported),
                                ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _StatusBadge(status: row.status),
                                        const Spacer(),
                                        Text(
                                          row.createdAt != null
                                              ? df.format(row.createdAt!)
                                              : '—',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Reporter: ${row.reporterEmail.isNotEmpty ? row.reporterEmail : row.reporterUid}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (row.targetUserId.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () => context.go(
                                          '/users/${row.targetUserId}',
                                        ),
                                        child: Text(
                                          'Owner: ${row.targetUserId}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      'Memory ID: ${row.publicMemoryId}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.shade200,
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Report message',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  row.message.isNotEmpty
                                      ? row.message
                                      : '— (no message text in Firestore)',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (row.reviewedAt != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Reviewed ${df.format(row.reviewedAt!)}'
                              '${row.reviewedByEmail != null && row.reviewedByEmail!.isNotEmpty ? ' · ${row.reviewedByEmail}' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (row.isOpen) ...[
                                OutlinedButton(
                                  onPressed: () => _markReviewed(row),
                                  child: const Text('Mark reviewed'),
                                ),
                                FilledButton(
                                  onPressed: row.publicMemoryId.isEmpty
                                      ? null
                                      : () => _hideMemory(row),
                                  child: const Text('Hide memory'),
                                ),
                              ],
                              OutlinedButton(
                                onPressed: row.publicMemoryId.isEmpty
                                    ? null
                                    : () => context.go('/public-memories'),
                                child: const Text('Public memories'),
                              ),
                            ],
                          ),
                        ],
                      ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final open = status == 'open';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: open ? Colors.orange.shade100 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        open ? 'OPEN' : status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: open ? Colors.orange.shade900 : Colors.green.shade900,
        ),
      ),
    );
  }
}
