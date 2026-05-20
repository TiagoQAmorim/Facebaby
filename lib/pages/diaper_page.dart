import 'package:flutter/material.dart';

import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../services/app_database.dart';
import '../services/firebase/diaper_cloud_sync.dart';
import '../services/firebase/firestore_service.dart';
import '../services/home_prefs.dart';
import '../services/scheduled_local_reminders.dart';
import '../theme/app_theme.dart';
import '../utils/portal_night_ui.dart';
import '../widgets/card_box.dart';

/// Registo de fraldas + histórico editável.
class DiaperPage extends StatefulWidget {
  const DiaperPage({super.key});

  @override
  State<DiaperPage> createState() => _DiaperPageState();
}

class _DiaperPageState extends State<DiaperPage> {
  static const int _historyPageSize = 10;

  final _currentBaby = CurrentBabyController.instance;
  final _scrollController = ScrollController();
  bool _saving = false;
  Future<List<Map<String, Object?>>>? _rowsFuture;
  Future<({DateTime? lastPee, DateTime? lastPoo})>? _peePooDashFuture;
  bool _historyExpanded = false;
  int _historyVisible = _historyPageSize;

  @override
  void initState() {
    super.initState();
    _currentBaby.addListener(_onBaby);
    _reload();
  }

  @override
  void dispose() {
    _currentBaby.removeListener(_onBaby);
    _scrollController.dispose();
    super.dispose();
  }

  void _onBaby() => _reload();

  void _reload() {
    final bid = _currentBaby.currentBabyId;
    setState(() {
      _historyVisible = _historyPageSize;
      _historyExpanded = false;
      _rowsFuture = bid == null
          ? null
          : AppDatabase.instance.listDiapers(babyId: bid, limit: 500);
      _peePooDashFuture = bid == null
          ? null
          : Future.wait([
              AppDatabase.instance.latestDiaperPeeRelatedAt(babyId: bid),
              AppDatabase.instance.latestDiaperPooRelatedAt(babyId: bid),
            ]).then((v) => (lastPee: v[0], lastPoo: v[1]));
    });
  }

  Future<void> _syncLocalReminders(int babyId) async {
    try {
      await ScheduledLocalReminders.sync(babyId: babyId);
    } catch (e, st) {
      debugPrint('DiaperPage._syncLocalReminders: $e\n$st');
    }
  }

  /// Tempo compacto (igual ao padrão da Home para “há …”).
  String _compactTimeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}\u00A0min';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h\u00A0${m.toString().padLeft(2, '0')}';
  }

  String _dashSubtitleLine(S s, DateTime? at) {
    if (at == null) return s.diaperDashNoRecordYet;
    if (DateTime.now().difference(at).inMinutes < 1) return s.diaperDashJustNow;
    return s.diaperDashAgoLine(_compactTimeAgo(at));
  }

  Future<void> _quickSaveDiaper(S s, int babyId, String kind) async {
    setState(() => _saving = true);
    try {
      final newId = await AppDatabase.instance.insertDiaperChange(
        babyId: babyId,
        changedAt: DateTime.now(),
        kind: kind,
      );
      DiaperCloudSync.pushLocalSoon(localBabyId: babyId, localDiaperId: newId);
      await _syncLocalReminders(babyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.diaperSavedOk)));
      _reload();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _diaperDashboard(S s, DateTime? lastPee, DateTime? lastPoo) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.green.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.diaperDashTitle,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: Colors.black.withAlpha(160),
                letterSpacing: 0.2),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DiaperDashCell(
                  title: s.diaperDashLastPee,
                  subtitle: _dashSubtitleLine(s, lastPee),
                  icon: Icons.water_drop_rounded,
                  tint: Colors.blue.withAlpha(200),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DiaperDashCell(
                  title: s.diaperDashLastPoo,
                  subtitle: _dashSubtitleLine(s, lastPoo),
                  icon: Icons.spa_rounded,
                  tint: AppTheme.green.withAlpha(240),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _kindLabel(S s, String kind) {
    switch (kind.trim().toLowerCase()) {
      case 'poo':
        return s.diaperKindPoo;
      case 'both':
        return s.diaperKindBoth;
      default:
        return s.diaperKindPee;
    }
  }

  Future<void> _editDiaper(S s, Map<String, Object?> row) async {
    final bid = _currentBaby.currentBabyId;
    final id = (row['id'] as num?)?.toInt();
    if (bid == null || id == null) return;

    var changed =
        DateTime.tryParse(row['changed_at'] as String? ?? '') ?? DateTime.now();
    var kind = (row['kind'] as String?) ?? 'pee';
    final noteCtrl =
        TextEditingController(text: (row['note'] as String?) ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 18,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 22,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.edit,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text(s.diaperChangedAtLabel),
                    subtitle: Text(
                      '${changed.day.toString().padLeft(2, '0')}/${changed.month.toString().padLeft(2, '0')}/${changed.year} '
                      '${changed.hour.toString().padLeft(2, '0')}:${changed.minute.toString().padLeft(2, '0')}',
                    ),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: changed,
                        firstDate: DateTime(changed.year - 2),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (d == null) return;
                      if (!ctx.mounted) return;
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(changed),
                      );
                      if (t == null) return;
                      setSheet(() {
                        changed =
                            DateTime(d.year, d.month, d.day, t.hour, t.minute);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: kind,
                    decoration: InputDecoration(
                      labelText: s.diaperKindLabel,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'pee', child: Text(s.diaperKindPee)),
                      DropdownMenuItem(
                          value: 'poo', child: Text(s.diaperKindPoo)),
                      DropdownMenuItem(
                          value: 'both', child: Text(s.diaperKindBoth)),
                    ],
                    onChanged: (v) => setSheet(() => kind = v ?? kind),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: s.diaperNoteOptional,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await AppDatabase.instance.updateDiaper(
                          id: id,
                          babyId: bid,
                          changedAt: changed,
                          kind: kind,
                          note: noteCtrl.text.trim().isEmpty
                              ? null
                              : noteCtrl.text.trim(),
                        );
                        await _syncLocalReminders(bid);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s.diaperUpdatedOk)));
                        _reload();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    },
                    child: Text(s.commonSave),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    noteCtrl.dispose();
  }

  Future<void> _confirmDelete(S s, Map<String, Object?> row) async {
    final bid = _currentBaby.currentBabyId;
    final id = (row['id'] as num?)?.toInt();
    if (bid == null || id == null) return;
    final cloudId = (row['cloud_id'] as String?)?.trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.delete),
        content: Text(s.confirmDelete),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final n = await AppDatabase.instance.deleteDiaper(id: id, babyId: bid);
      await _syncLocalReminders(bid);
      if (!mounted) return;
      if (n > 0) {
        if (cloudId != null && cloudId.isNotEmpty) {
          try {
            await FirestoreService.instance.deleteEvent(cloudId);
          } catch (_) {}
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.deletedOk)));
        _reload();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final babyId = _currentBaby.currentBabyId;

    return PortalNightUi.listen((context, night) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PortalNightUi.appBar(s.shortcutDiaper, night: night),
        body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CardBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.baby_changing_station_rounded,
                            color: AppTheme.green, size: 40),
                        const SizedBox(height: 14),
                        Text(
                          s.shortcutDiaper,
                          style: PortalNightUi.cardTitleStyle(fontSize: 22),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.diaperIntro,
                          style: PortalNightUi.cardSubtitleStyle(fontSize: 14)
                              .copyWith(height: 1.45),
                        ),
                        const SizedBox(height: 14),
                        if (babyId != null)
                          ValueListenableBuilder<bool>(
                            valueListenable: HomePrefs.diaperAlertsEnabled,
                            builder: (context, enabled, _) {
                              return SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                secondary: const Icon(
                                  Icons.notifications_active_outlined,
                                  color: AppTheme.green,
                                ),
                                title: Text(
                                  s.diaperToggleAlerts,
                                  style: PortalNightUi.cardTitleStyle(
                                      fontSize: 15),
                                ),
                                subtitle: Text(
                                  s.diaperToggleAlertsSubtitle,
                                  style: PortalNightUi.cardSubtitleStyle(
                                      fontSize: 12),
                                ),
                                value: enabled,
                                activeThumbColor: AppTheme.green,
                                onChanged: (v) =>
                                    HomePrefs.setDiaperAlertsEnabled(v),
                              );
                            },
                          ),
                        if (babyId != null) const SizedBox(height: 8),
                        const SizedBox(height: 16),
                        if (babyId == null)
                          Text(s.feedingNoBabyHint,
                              style: TextStyle(
                                  color: Colors.black.withAlpha(140),
                                  fontWeight: FontWeight.w700))
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _saving
                                          ? null
                                          : () => _quickSaveDiaper(
                                              s, babyId, 'pee'),
                                      icon:
                                          const Icon(Icons.water_drop_rounded),
                                      label: Text(s.diaperKindPee),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _saving
                                          ? null
                                          : () => _quickSaveDiaper(
                                              s, babyId, 'poo'),
                                      icon: const Icon(Icons.spa_rounded),
                                      label: Text(s.diaperKindPoo),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.standard,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: _saving
                                    ? null
                                    : () => _quickSaveDiaper(s, babyId, 'both'),
                                icon: Icon(Icons.layers_rounded,
                                    color: Colors.white.withAlpha(250)),
                                label: Text(s.diaperKindBoth),
                              ),
                              const SizedBox(height: 14),
                              FutureBuilder<
                                  ({DateTime? lastPee, DateTime? lastPoo})>(
                                future: _peePooDashFuture,
                                builder: (context, dashSnap) {
                                  if (_peePooDashFuture == null)
                                    return const SizedBox.shrink();
                                  if (dashSnap.connectionState ==
                                      ConnectionState.waiting) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(99),
                                        child: LinearProgressIndicator(
                                          minHeight: 6,
                                          color: AppTheme.green,
                                          backgroundColor:
                                              AppTheme.green.withAlpha(40),
                                        ),
                                      ),
                                    );
                                  }
                                  final d = dashSnap.data;
                                  if (d == null) return const SizedBox.shrink();
                                  return _diaperDashboard(
                                      s, d.lastPee, d.lastPoo);
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (babyId != null) ...[
                    const SizedBox(height: 22),
                    Text(s.diaperHistoryTitle,
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Colors.black.withAlpha(180))),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _historyExpanded = !_historyExpanded;
                          _historyVisible = _historyPageSize;
                        }),
                        icon: Icon(_historyExpanded
                            ? Icons.expand_less_rounded
                            : Icons.history_rounded),
                        label: Text(_historyExpanded
                            ? s.historyHideButton
                            : s.historyShowButton),
                      ),
                    ),
                    if (_historyExpanded) ...[
                      const SizedBox(height: 10),
                      FutureBuilder<List<Map<String, Object?>>>(
                        future: _rowsFuture,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                                padding: EdgeInsets.all(24),
                                child:
                                    Center(child: CircularProgressIndicator()));
                          }
                          final rows = snap.data ?? const [];
                          if (rows.isEmpty) {
                            return Text(s.diaperHistoryEmpty,
                                style: TextStyle(
                                    color: Colors.black.withAlpha(130)));
                          }
                          final visibleRows = rows.take(_historyVisible);
                          return Column(
                            children: [
                              ...visibleRows.map((row) {
                                final id = (row['id'] as num?)?.toInt();
                                final dt = DateTime.tryParse(
                                    row['changed_at'] as String? ?? '');
                                final kind = (row['kind'] as String?) ?? 'pee';
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 0,
                                  color: const Color(0xFFF5F6F8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                        color: Colors.black.withAlpha(14)),
                                  ),
                                  child: ListTile(
                                    title: Text(_kindLabel(s, kind),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    subtitle: Text(
                                      dt == null
                                          ? '—'
                                          : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
                                              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                          color: Colors.black.withAlpha(130),
                                          fontWeight: FontWeight.w600),
                                    ),
                                    trailing: id == null
                                        ? null
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: s.edit,
                                                onPressed: () =>
                                                    _editDiaper(s, row),
                                                icon: Icon(Icons.edit_outlined,
                                                    color: AppTheme.green
                                                        .withAlpha(220)),
                                              ),
                                              IconButton(
                                                tooltip: s.delete,
                                                onPressed: () =>
                                                    _confirmDelete(s, row),
                                                icon: Icon(Icons.delete_outline,
                                                    color: Colors.red
                                                        .withAlpha(200)),
                                              ),
                                            ],
                                          ),
                                  ),
                                );
                              }),
                              if (_historyVisible < rows.length)
                                TextButton.icon(
                                  onPressed: () => setState(() =>
                                      _historyVisible += _historyPageSize),
                                  icon: const Icon(Icons.expand_more_rounded),
                                  label: Text(s.historyViewMoreButton),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    });
  }
}

class _DiaperDashCell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;

  const _DiaperDashCell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withAlpha(55)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: tint),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: Colors.black.withAlpha(200),
                        height: 1.15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                  height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
