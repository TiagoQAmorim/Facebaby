import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/admin_models.dart';
import '../services/admin_repository.dart';
import '../widgets/admin_layout.dart';
import '../widgets/admin_pagination.dart';
import '../widgets/admin_storage_image.dart';
import '../widgets/admin_table_viewport.dart';

class PublicMemoriesPage extends StatefulWidget {
  const PublicMemoriesPage({super.key});

  @override
  State<PublicMemoriesPage> createState() => _PublicMemoriesPageState();
}

class _PublicMemoriesPageState extends State<PublicMemoriesPage> {
  final _pagination = AdminPaginationState();
  List<PublicMemoryRow> _rows = [];
  bool _loading = true;
  String? _error;

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
      final result = await AdminRepository.instance.fetchPublicMemoriesPage(
        pageSize: _pagination.pageSize,
        newestFirst: _pagination.newestFirst,
        startAfter: _pagination.startAfter,
      );
      _pagination.applyPage(
        more: result.hasMore,
        lastDocument: result.lastDocument,
      );
      _rows = result.items;
    } catch (e) {
      _error = e.toString();
      _rows = [];
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
      columns: const [
        DataColumn(label: Text('Photo')),
        DataColumn(label: Text('Baby')),
        DataColumn(label: Text('User')),
        DataColumn(label: Text('Email')),
        DataColumn(label: Text('Description')),
        DataColumn(label: Text('Week')),
        DataColumn(label: Text('Visibility')),
        DataColumn(label: Text('Likes')),
        DataColumn(label: Text('Created')),
        DataColumn(label: Text('Actions')),
      ],
      rows: [
        for (final r in _rows)
          DataRow(
            cells: [
              DataCell(
                AdminStorageImage(
                  httpsUrl: r.photoUrl,
                  publicMemoryDocId: r.id,
                  userId: r.userId,
                  babyId: r.babyId,
                  badgeId: r.badgeId,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
              DataCell(Text(r.babyName)),
              DataCell(Text(r.userName)),
              DataCell(Text(r.email)),
              DataCell(
                SizedBox(
                  width: 200,
                  child: Text(
                    r.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(Text(r.submissionWeek)),
              DataCell(Text(r.visibility)),
              DataCell(Text('${r.likes}')),
              DataCell(Text(r.createdAt != null ? fmt.format(r.createdAt!) : '—')),
              DataCell(
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    final repo = AdminRepository.instance;
                    switch (v) {
                      case 'hide':
                        await repo.hidePublicMemory(r.id);
                      case 'restore':
                        await repo.restorePublicMemory(r.id);
                      case 'inappropriate':
                        await repo.markInappropriate(r.id);
                      case 'family':
                        context.go('/users/${r.userId}');
                    }
                    await _loadPage();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'hide', child: Text('Hide')),
                    PopupMenuItem(value: 'restore', child: Text('Restore')),
                    PopupMenuItem(value: 'inappropriate', child: Text('Mark inappropriate')),
                    PopupMenuItem(value: 'family', child: Text('Open family')),
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
        emptyMessage:
            _rows.isEmpty && _error == null ? 'No public memories found.' : null,
        header: AdminPageHeader(
          title: 'Public Memories',
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
        footer: _paginationBar(),
        table: table,
      ),
    );
  }
}
