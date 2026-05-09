import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../i18n/app_i18n.dart';
import '../services/app_database.dart';
import '../services/notification_nav.dart';
import '../theme/app_theme.dart';
import '../utils/portal_layout.dart';

/// Lista notificações locais registadas nos últimos 3 dias (mostradas ou agendadas).
class NotificationsInboxPage extends StatefulWidget {
  const NotificationsInboxPage({super.key});

  @override
  State<NotificationsInboxPage> createState() => _NotificationsInboxPageState();
}

class _NotificationsInboxPageState extends State<NotificationsInboxPage> {
  List<Map<String, Object?>> _rows = const [];
  bool _loading = true;
  bool _selectionMode = false;
  final Set<int> _selectedIds = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final since = DateTime.now().subtract(const Duration(days: 3));
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (!mounted) return;
        setState(() {
          _rows = const [];
          _loading = false;
        });
        return;
      }
      final rowsRaw = await AppDatabase.instance.listNotificationLogSince(uid: uid, since: since);
      final now = DateTime.now();
      // Inbox mostra o que já aconteceu (entregue/mostrado). Não antecipa agendamentos futuros
      // para não “spoilar” notificações (ex.: vacina daqui a 2 dias).
      final rows = rowsRaw.where((r) {
        final kind = (r['kind'] as String?)?.trim();
        if (kind != 'scheduled') return true;
        final occ = _parseOccurred(r);
        return !occ.isAfter(now);
      }).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rows = const [];
        _loading = false;
      });
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ids = _selectedIds.toList(growable: false);
    if (ids.isEmpty) return;
    await AppDatabase.instance.deleteNotificationLogs(uid: uid, ids: ids);
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
    await _load();
  }

  Set<int> _everySelectableRowId() {
    final ids = <int>{};
    for (final row in _rows) {
      final id = (row['id'] as num?)?.toInt();
      if (id != null) ids.add(id);
    }
    return ids;
  }

  bool? _selectAllCheckboxValue() {
    final every = _everySelectableRowId();
    if (every.isEmpty) return false;
    var nChosen = 0;
    for (final id in every) {
      if (_selectedIds.contains(id)) nChosen++;
    }
    if (nChosen == 0) return false;
    if (nChosen == every.length) return true;
    return null;
  }

  void _toggleSelectAll() {
    final every = _everySelectableRowId();
    if (every.isEmpty) return;
    setState(() {
      if (_selectedIds.containsAll(every)) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(every);
      }
    });
  }

  void _beginSelectionWith(int rowId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(rowId);
    });
  }

  static DateTime _parseOccurred(Map<String, Object?> row) {
    final raw = row['occurred_at'] as String?;
    return DateTime.tryParse(raw ?? '') ?? DateTime.now();
  }

  static DateTime _parseCreatedAt(Map<String, Object?> row) {
    final raw = row['created_at'] as String?;
    final p = DateTime.tryParse(raw ?? '');
    return p ?? _parseOccurred(row);
  }

  /// Agrupar/listar pela data mais “recente entre evento lembrado” e momento em que ficou registado —
  /// evita cabeceiras como “mês passado” quando o registo só existiu há poucos dias.
  static DateTime _displayInstant(Map<String, Object?> row) {
    final occ = _parseOccurred(row);
    final cre = _parseCreatedAt(row);
    return occ.isBefore(cre) ? cre : occ;
  }

  String _sectionLabel(S s, DateTime day) {
    final now = DateTime.now();
    final t = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    if (d == t) return s.homeTodayLabel;
    if (d == t.subtract(const Duration(days: 1))) return s.homeYesterdayLabel;
    return '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
  }

  String _timeHm(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _kindLabel(S s, String? kind) {
    switch (kind) {
      case 'scheduled':
        return s.notificationsKindScheduled;
      case 'shown':
      default:
        return s.notificationsKindShown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final groups = <DateTime, List<Map<String, Object?>>>{};
    for (final row in _rows) {
      final at = _displayInstant(row);
      final day = DateTime(at.year, at.month, at.day);
      groups.putIfAbsent(day, () => []).add(row);
    }
    final sortedDays = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text(s.notificationsInboxTitle),
        actions: [
          if (!_loading && _rows.isNotEmpty)
            IconButton(
              tooltip: _selectionMode ? s.cancel : s.edit,
              onPressed: _toggleSelectionMode,
              icon: Icon(_selectionMode ? Icons.close_rounded : Icons.checklist_rounded),
            ),
          if (_selectionMode)
            IconButton(
              tooltip: s.delete,
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Text(
              s.notificationsInboxSubtitle,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: portalSp(context, 12),
                color: AppTheme.textMuted,
                height: 1.35,
              ),
            ),
            if (_selectionMode && !_loading && _rows.isNotEmpty) ...[
              const SizedBox(height: 10),
              Material(
                color: AppTheme.card,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppTheme.textMuted.withAlpha(36)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _toggleSelectAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Checkbox.adaptive(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          value: _selectAllCheckboxValue(),
                          tristate: true,
                          onChanged: (_) => _toggleSelectAll(),
                          activeColor: AppTheme.primaryPurple,
                        ),
                        Expanded(
                          child: Text(
                            s.notificationsSelectAll,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: portalSp(context, 13),
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (_loading)
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.35,
                child: const Center(child: CircularProgressIndicator()),
              )
            else if (_rows.isEmpty)
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.35,
                child: Center(
                  child: Text(
                    s.notificationsEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: portalSp(context, 15),
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              )
            else
              for (final day in sortedDays) ...[
                Padding(
                  padding: EdgeInsets.only(bottom: 8, top: day == sortedDays.first ? 0 : 18),
                  child: Text(
                    _sectionLabel(s, day),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: portalSp(context, 13),
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                for (final row in groups[day]!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NotificationTile(
                      id: (row['id'] as num?)?.toInt(),
                      selectionMode: _selectionMode,
                      selectedIds: _selectedIds,
                      onSelectionChanged: () => setState(() {}),
                      onBeginSelectionRow: _beginSelectionWith,
                      occurredAt: _displayInstant(row),
                      title: (row['title'] as String?) ?? '',
                      body: (row['body'] as String?) ?? '',
                      payload: row['payload'] as String?,
                      kindLabel: _kindLabel(s, row['kind'] as String?),
                      timeHm: _timeHm,
                      openHint: s.notificationsOpenTarget,
                    ),
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.id,
    required this.selectionMode,
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.onBeginSelectionRow,
    required this.occurredAt,
    required this.title,
    required this.body,
    required this.payload,
    required this.kindLabel,
    required this.timeHm,
    required this.openHint,
  });

  final int? id;
  final bool selectionMode;
  final Set<int> selectedIds;
  final VoidCallback onSelectionChanged;
  /// Ativa modo seleção e inclui esta linha (uso: toque prolongado quando ainda não em modo edição).
  final void Function(int rowId) onBeginSelectionRow;
  final DateTime occurredAt;
  final String title;
  final String body;
  final String? payload;
  final String kindLabel;
  final String Function(DateTime) timeHm;
  final String openHint;

  @override
  Widget build(BuildContext context) {
    final p = payload?.trim();
    final hasPayload = p != null && p.isNotEmpty;
    final rowId = id;
    final checked = rowId != null && selectedIds.contains(rowId);
    return Material(
      color: AppTheme.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.textMuted.withAlpha(36)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (selectionMode) {
            if (rowId == null) return;
            if (checked) {
              selectedIds.remove(rowId);
            } else {
              selectedIds.add(rowId);
            }
            onSelectionChanged();
            return;
          }
          if (hasPayload) NotificationNav.openFromPayload(context, p);
        },
        onLongPress: () {
          if (rowId == null) return;
          if (!selectionMode) {
            onBeginSelectionRow(rowId);
            return;
          }
          if (checked) {
            selectedIds.remove(rowId);
          } else {
            selectedIds.add(rowId);
          }
          onSelectionChanged();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode) ...[
                    Checkbox.adaptive(
                      value: checked,
                      onChanged: rowId == null
                          ? null
                          : (v) {
                              if (v == true) {
                                selectedIds.add(rowId);
                              } else if (v == false) {
                                selectedIds.remove(rowId);
                              }
                              onSelectionChanged();
                            },
                      activeColor: AppTheme.primaryPurple,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: portalSp(context, 14),
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    timeHm(occurredAt),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: portalSp(context, 12),
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: TextStyle(
                  fontSize: portalSp(context, 13),
                  height: 1.35,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.softMint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      kindLabel,
                      style: TextStyle(
                        fontSize: portalSp(context, 10),
                        fontWeight: FontWeight.w800,
                        color: AppTheme.secondary,
                      ),
                    ),
                  ),
                  if (hasPayload) ...[
                    const SizedBox(width: 8),
                    Text(
                      openHint,
                      style: TextStyle(
                        fontSize: portalSp(context, 10),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
