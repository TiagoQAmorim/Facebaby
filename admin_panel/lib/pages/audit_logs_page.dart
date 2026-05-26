import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/admin_models.dart';
import '../services/admin_audit_service.dart';
import '../services/admin_repository.dart';
import '../widgets/admin_layout.dart';
import '../widgets/admin_table_viewport.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  List<AdminAuditLogRow> _all = [];
  bool _loading = true;
  String? _error;

  String? _filterAdminUid;
  String? _filterAction;
  final _userQuery = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _userQuery.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _all = await AdminRepository.instance.fetchAuditLogs();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AdminAuditLogRow> get _filtered {
    final q = _userQuery.text.trim().toLowerCase();
    return _all.where((row) {
      final filterAdmin = _filterAdminUid;
      if (filterAdmin != null &&
          filterAdmin.isNotEmpty &&
          row.adminUid != filterAdmin) {
        return false;
      }
      final filterAct = _filterAction;
      if (filterAct != null &&
          filterAct.isNotEmpty &&
          row.action != filterAct) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay = '${row.targetUserUid} ${row.targetUserEmail}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      final created = row.createdAt;
      final from = _dateFrom;
      if (from != null && created != null) {
        final start = DateTime(from.year, from.month, from.day);
        if (created.isBefore(start)) return false;
      }
      final to = _dateTo;
      if (to != null && created != null) {
        final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
        if (created.isAfter(end)) return false;
      }
      return true;
    }).toList();
  }

  List<({String uid, String email})> get _adminOptions {
    final map = <String, String>{};
    for (final row in _all) {
      if (row.adminUid.isEmpty) continue;
      map[row.adminUid] = row.adminEmail.isNotEmpty ? row.adminEmail : row.adminUid;
    }
    final list = map.entries
        .map((e) => (uid: e.key, email: e.value))
        .toList()
      ..sort((a, b) => a.email.compareTo(b.email));
    return list;
  }

  Future<void> _pickDate({required bool from}) async {
    final initial = (from ? _dateFrom : _dateTo) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _filterAdminUid = null;
      _filterAction = null;
      _userQuery.clear();
      _dateFrom = null;
      _dateTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final rows = _filtered;

    final wide = AdminLayout.isWide(context);
    final filtersAndTable = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Audit Logs',
            actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 640;
                  final adminDropdown = DropdownButtonFormField<String?>(
                    isExpanded: true,
                    value: _filterAdminUid,
                    decoration: const InputDecoration(
                      labelText: 'Admin',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All admins')),
                      for (final a in _adminOptions)
                        DropdownMenuItem(
                          value: a.uid,
                          child: Text(a.email, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _filterAdminUid = v),
                  );
                  final actionDropdown = DropdownButtonFormField<String?>(
                    isExpanded: true,
                    value: _filterAction,
                    decoration: const InputDecoration(
                      labelText: 'Action',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All actions')),
                      for (final a in AdminAuditAction.all)
                        DropdownMenuItem(
                          value: a,
                          child: Text(
                            adminAuditActionLabel(a),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _filterAction = v),
                  );
                  final userField = TextField(
                    controller: _userQuery,
                    decoration: const InputDecoration(
                      labelText: 'User (uid or email)',
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                    onChanged: (_) => setState(() {}),
                  );
                  final dateRow = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(from: true),
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _dateFrom == null
                              ? 'From date'
                              : fmt.format(_dateFrom ?? DateTime.now()).split(' ').first,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(from: false),
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _dateTo == null
                              ? 'To date'
                              : fmt.format(_dateTo ?? DateTime.now()).split(' ').first,
                        ),
                      ),
                      TextButton(onPressed: _clearFilters, child: const Text('Clear filters')),
                    ],
                  );

                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        adminDropdown,
                        const SizedBox(height: 12),
                        actionDropdown,
                        const SizedBox(height: 12),
                        userField,
                        const SizedBox(height: 12),
                        dateRow,
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: adminDropdown),
                          const SizedBox(width: 12),
                          Expanded(child: actionDropdown),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: userField),
                        ],
                      ),
                      const SizedBox(height: 12),
                      dateRow,
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${rows.length} of ${_all.length} entries',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.5), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (wide)
            Expanded(
              child: Card(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                _error ?? '',
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          )
                        : rows.isEmpty
                            ? const Center(
                                child: Text('No audit logs match the filters.'),
                              )
                            : AdminTableViewport(
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Admin')),
                                    DataColumn(label: Text('Action')),
                                    DataColumn(label: Text('Target user')),
                                    DataColumn(label: Text('Details')),
                                  ],
                                  rows: [
                                    for (final r in rows)
                                      DataRow(
                                        cells: [
                                          DataCell(Text(
                                            r.createdAt != null
                                                ? fmt.format(r.createdAt ?? DateTime.now())
                                                : '—',
                                          )),
                                          DataCell(
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 200),
                                              child: Text(
                                                r.adminEmail.isNotEmpty ? r.adminEmail : r.adminUid,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(adminAuditActionLabel(r.action))),
                                          DataCell(
                                            r.targetUserUid.isNotEmpty
                                                ? InkWell(
                                                    onTap: () => context.go('/users/${r.targetUserUid}'),
                                                    child: Text(
                                                      r.targetUserEmail.isNotEmpty
                                                          ? r.targetUserEmail
                                                          : r.targetUserUid,
                                                      style: const TextStyle(
                                                        decoration: TextDecoration.underline,
                                                        color: Color(0xFF1565C0),
                                                      ),
                                                    ),
                                                  )
                                                : const Text('—'),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 280,
                                              child: Text(
                                                r.details,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
              ),
            )
          else
            Card(
              child: _loading
                  ? const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _error ?? '',
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      : rows.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('No audit logs match the filters.'),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Admin')),
                                  DataColumn(label: Text('Action')),
                                  DataColumn(label: Text('Target user')),
                                  DataColumn(label: Text('Details')),
                                ],
                                rows: [
                                  for (final r in rows)
                                    DataRow(
                                      cells: [
                                        DataCell(Text(
                                          r.createdAt != null
                                              ? fmt.format(
                                                  r.createdAt ?? DateTime.now(),
                                                )
                                              : '—',
                                        )),
                                        DataCell(
                                          ConstrainedBox(
                                            constraints:
                                                const BoxConstraints(maxWidth: 200),
                                            child: Text(
                                              r.adminEmail.isNotEmpty
                                                  ? r.adminEmail
                                                  : r.adminUid,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                            Text(adminAuditActionLabel(r.action))),
                                        DataCell(
                                          r.targetUserUid.isNotEmpty
                                              ? InkWell(
                                                  onTap: () => context.go(
                                                    '/users/${r.targetUserUid}',
                                                  ),
                                                  child: Text(
                                                    r.targetUserEmail.isNotEmpty
                                                        ? r.targetUserEmail
                                                        : r.targetUserUid,
                                                    style: const TextStyle(
                                                      decoration:
                                                          TextDecoration.underline,
                                                      color: Color(0xFF1565C0),
                                                    ),
                                                  ),
                                                )
                                              : const Text('—'),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 280,
                                            child: Text(
                                              r.details,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
            ),
          const SizedBox(height: 28),
        ],
      );

    return AdminPageScaffold(
      child: wide
          ? filtersAndTable
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: filtersAndTable),
              ],
            ),
    );
  }
}
