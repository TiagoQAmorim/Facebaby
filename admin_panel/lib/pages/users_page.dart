import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/admin_models.dart';
import '../services/admin_auth_service.dart';
import '../services/admin_permissions.dart';
import '../services/admin_repository.dart';
import '../widgets/admin_layout.dart';
import '../widgets/admin_pagination.dart';
import '../widgets/admin_table_viewport.dart';
import '../widgets/confirm_dialog.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _pagination = AdminPaginationState();
  final Set<String> _selectedUids = {};
  List<AdminUserRow> _rows = [];
  bool _loading = true;
  String? _error;

  bool get _canManage =>
      AdminPermissions.canManageUsers(AdminAuthService.instance.admin);

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AdminRepository.instance.fetchUsersPage(
        pageSize: _pagination.pageSize,
        newestFirst: _pagination.newestFirst,
        startAfter: _pagination.startAfter,
      );
      _pagination.applyPage(
        more: result.hasMore,
        lastDocument: result.lastDocument,
      );
      _rows = result.items;
      _selectedUids.removeWhere(
        (uid) => !_rows.any((r) => r.uid == uid),
      );
    } catch (e) {
      _error = e.toString();
      _rows = [];
      _selectedUids.clear();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSortChanged(bool newestFirst) {
    _pagination.setNewestFirst(newestFirst);
    _loadPage();
  }

  void _goNext() {
    _pagination.nextPage();
    _loadPage();
  }

  void _goPrevious() {
    _pagination.previousPage();
    _loadPage();
  }

  void _toggleRow(String uid, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedUids.add(uid);
      } else {
        _selectedUids.remove(uid);
      }
    });
  }

  void _toggleSelectAll(bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedUids.addAll(_rows.map((r) => r.uid));
      } else {
        _selectedUids.clear();
      }
    });
  }

  void _clearSelection() {
    if (_selectedUids.isEmpty) return;
    setState(_selectedUids.clear);
  }

  Future<void> _suspend(AdminUserRow row) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Suspend user',
      message: 'Are you sure you want to suspend this user?',
      confirmLabel: 'Suspend',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Suspension reason (optional)'),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Reason for audit log'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Skip')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    await AdminRepository.instance.suspendUser(
      uid: row.uid,
      reason: reason != null && reason.isNotEmpty ? reason : null,
    );
    await _loadPage();
  }

  Future<UserPlan?> _pickPlan({String? title}) async {
    return showDialog<UserPlan>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title ?? 'Change plan'),
        children: UserPlan.values
            .map(
              (p) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, p),
                child: Text(planLabel(p)),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _changePlan(AdminUserRow row) async {
    final plan = await _pickPlan();
    if (plan == null) return;
    await AdminRepository.instance.setUserPlan(row.uid, plan);
    await _loadPage();
  }

  Future<void> _bulkChangePlan() async {
    if (_selectedUids.isEmpty || !_canManage) return;
    final n = _selectedUids.length;
    final plan = await _pickPlan(title: 'Change plan for $n users');
    if (plan == null) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Apply to $n users',
      message:
          'Set plan "${planLabel(plan)}" for all selected users on this page?',
      confirmLabel: 'Apply',
    );
    if (!ok || !context.mounted) return;
    setState(() => _loading = true);
    try {
      await AdminRepository.instance.setUserPlansBulk(
        _selectedUids.toList(),
        plan,
      );
      _selectedUids.clear();
      await _loadPage();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Widget? _selectionBar() {
    if (!_canManage || _selectedUids.isEmpty) return null;
    final n = _selectedUids.length;
    return Material(
      color: const Color(0xFFE8F0FE),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '$n selected',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            FilledButton.icon(
              onPressed: _bulkChangePlan,
              icon: const Icon(Icons.card_membership_outlined, size: 18),
              label: const Text('Change access / plan'),
            ),
            TextButton(onPressed: _clearSelection, child: const Text('Clear')),
          ],
        ),
      ),
    );
  }

  Widget _paginationBar() {
    return AdminPaginationBar(
      pageIndex: _pagination.pageIndex,
      pageSize: _pagination.pageSize,
      canGoPrevious: _pagination.canGoPrevious,
      canGoNext: _pagination.canGoNext,
      newestFirst: _pagination.newestFirst,
      onNewestFirstChanged: _onSortChanged,
      onPrevious: _goPrevious,
      onNext: _goNext,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final table = DataTable(
      showCheckboxColumn: _canManage,
      headingRowHeight: 48,
      dataRowMinHeight: 48,
      onSelectAll: _canManage ? _toggleSelectAll : null,
      columns: const [
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Email')),
        DataColumn(label: Text('Plan')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Created')),
        DataColumn(label: Text('Last login')),
        DataColumn(label: Text('Baby')),
        DataColumn(label: Text('Memories')),
        DataColumn(label: Text('Public')),
        DataColumn(label: Text('Actions')),
      ],
      rows: [
        for (final r in _rows)
          DataRow(
            selected: _selectedUids.contains(r.uid),
            onSelectChanged: _canManage
                ? (selected) => _toggleRow(r.uid, selected)
                : null,
            cells: [
              DataCell(
                InkWell(
                  onTap: () => context.go('/users/${r.uid}'),
                  child: Text(
                    r.name,
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ),
              ),
              DataCell(Text(r.email)),
              DataCell(Text(planLabel(r.plan))),
              DataCell(Text(r.status.name)),
              DataCell(Text(r.createdAt != null ? fmt.format(r.createdAt!) : '—')),
              DataCell(Text(r.lastLoginAt != null ? fmt.format(r.lastLoginAt!) : '—')),
              DataCell(Text(r.babyName)),
              DataCell(Text('${r.memoriesCount}')),
              DataCell(Text('${r.publicMemoriesCount}')),
              DataCell(
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'family':
                        context.go('/users/${r.uid}');
                      case 'suspend':
                        await _suspend(r);
                      case 'reactivate':
                        await AdminRepository.instance.reactivateUser(r.uid);
                        await _loadPage();
                      case 'plan':
                        await _changePlan(r);
                      case 'public':
                        context.go('/public-memories');
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'family', child: Text('View family')),
                    if (_canManage && r.status == UserStatus.active)
                      const PopupMenuItem(value: 'suspend', child: Text('Suspend user')),
                    if (_canManage && r.status == UserStatus.suspended)
                      const PopupMenuItem(value: 'reactivate', child: Text('Reactivate user')),
                    if (_canManage)
                      const PopupMenuItem(value: 'plan', child: Text('Change plan')),
                    const PopupMenuItem(value: 'public', child: Text('View public memories')),
                  ],
                ),
              ),
            ],
          ),
      ],
    );

    return AdminPageScaffold(
      child: AdminTablePageLayout(
        loading: _loading,
        error: _error,
        emptyMessage: _rows.isEmpty && _error == null ? 'No users found.' : null,
        header: AdminPageHeader(
          title: 'Users',
          actions: [
            IconButton(
              onPressed: () {
                _pagination.reset();
                _loadPage();
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        selectionBar: _selectionBar(),
        footer: _paginationBar(),
        table: table,
      ),
    );
  }
}
