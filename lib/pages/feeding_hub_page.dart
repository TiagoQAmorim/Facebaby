import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../controllers/breastfeeding_timer_controller.dart';
import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../models/feeding_record.dart';
import '../services/app_database.dart';
import '../services/firebase/feeding_cloud_sync.dart';
import '../services/firebase/firestore_service.dart';
import '../services/home_prefs.dart';
import '../services/measurement_units_prefs.dart';
import '../services/scheduled_local_reminders.dart';
import '../services/portal_layout_prefs.dart';
import '../theme/app_theme.dart';
import '../utils/measurement_format.dart';
import '../utils/portal_night_ui.dart';
import '../utils/portal_time_of_day.dart';
import '../widgets/android_exact_alarm_card.dart';
import '../widgets/card_option_picker_field.dart';

/// Hub de **Alimentação**: abas Amamentação · Mamadeira · Sólidos (layout próximo ao mock).
class FeedingHubPage extends StatefulWidget {
  final String appBarTitle;

  const FeedingHubPage({super.key, required this.appBarTitle});

  @override
  State<FeedingHubPage> createState() => _FeedingHubPageState();
}

class _FeedingHubPageState extends State<FeedingHubPage>
    with SingleTickerProviderStateMixin {
  static const int _historyPageSize = 10;

  /// Peito esquerdo — contraste forte no donut (evita duas tonalidades só de roxo).
  static const Color _pieBreastLeft = Color(0xFF0F766E);

  /// Peito direito — cor distinta do esquerdo.
  static const Color _pieBreastRight = Color(0xFFB83280);
  static const Color _breastCardBg = Color(0xFFF3EEFF); // lavanda
  static const Color _bottleCardBg = Color(0xFFFFF0F6); // rosinha
  static const Color _solidsCardBg = Color(0xFFFFF3E8); // pêssego

  static const BorderSide _pieSectionDivider =
      BorderSide(color: Colors.white, width: 3.5);

  static const TextStyle _pieArcTitleStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w900,
    fontSize: 15,
    height: 1.05,
    shadows: [
      Shadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x66000000)),
      Shadow(offset: Offset(0, 0), blurRadius: 8, color: Color(0x33000000)),
    ],
  );

  late TabController _tabController;
  final _currentBaby = CurrentBabyController.instance;
  final _breastScrollController = ScrollController();
  final _bottleScrollController = ScrollController();
  final _solidsScrollController = ScrollController();
  static final BreastfeedingTimerController _breastTimer =
      BreastfeedingTimerController.instance;

  final _bottleMlCtrl = TextEditingController();
  final _bottleNoteCtrl = TextEditingController();
  final _solidNoteCtrl = TextEditingController();

  Future<List<Map<String, Object?>>>? _feedingsFuture;

  /// Lista dedicada ao histórico editável; a UI mostra em lotes de 10.
  Future<List<Map<String, Object?>>>? _overviewFeedingsFuture;

  bool _overviewExpanded = false;
  int _feedingHistoryVisible = _historyPageSize;

  final GlobalKey _overviewResultsKeyBreast = GlobalKey();
  final GlobalKey _overviewResultsKeyBottle = GlobalKey();
  final GlobalKey _overviewResultsKeySolids = GlobalKey();

  void _onBreastTimerTick() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentBaby.addListener(_onBabyChanged);
    _breastTimer.addListener(_onBreastTimerTick);
    _refreshFeedingsFuture();
  }

  @override
  void dispose() {
    _currentBaby.removeListener(_onBabyChanged);
    _breastTimer.removeListener(_onBreastTimerTick);
    _breastScrollController.dispose();
    _bottleScrollController.dispose();
    _solidsScrollController.dispose();
    _tabController.dispose();
    _bottleMlCtrl.dispose();
    _bottleNoteCtrl.dispose();
    _solidNoteCtrl.dispose();
    super.dispose();
  }

  void _scrollOverviewResultsIntoView(GlobalKey resultsKey) {
    void scroll() {
      if (!mounted) return;
      final ctx = resultsKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.05,
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => scroll());
    Future.delayed(const Duration(milliseconds: 260), scroll);
  }

  void _onBabyChanged() {
    _breastTimer.discardIfBabyMismatch(_currentBaby.currentBabyId);
    _feedingHistoryVisible = _historyPageSize;
    _refreshFeedingsFuture();
    if (mounted) setState(() {});
  }

  int? get _babyId => _currentBaby.currentBabyId;

  void _refreshFeedingsFuture() {
    final id = _babyId;
    if (id == null) {
      _feedingsFuture = null;
      _overviewFeedingsFuture = null;
      return;
    }
    _feedingsFuture = AppDatabase.instance.listFeedings(babyId: id, limit: 500);
    _overviewFeedingsFuture =
        AppDatabase.instance.listFeedings(babyId: id, limit: 500);
    if (mounted) setState(() {});
  }

  Future<void> _syncLocalReminders(int babyId) async {
    try {
      await ScheduledLocalReminders.sync(babyId: babyId);
    } catch (e, st) {
      debugPrint('FeedingHubPage._syncLocalReminders: $e\n$st');
    }
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  String _fmtHms(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${_two(h)}:${_two(m)}:${_two(s)}';
  }

  String _fmtDurationShort(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inHours < 1) return '${d.inMinutes} min';
    final m = d.inMinutes.remainder(60);
    return m == 0 ? '${d.inHours}h' : '${d.inHours}h ${m}min';
  }

  Duration _elapsedBreastDisplay(String side) {
    final bid = _babyId;
    if (bid == null || _breastTimer.babyId != bid) return Duration.zero;
    return _breastTimer.elapsedForSide(side);
  }

  bool _breastCircleActive(String side) {
    final bid = _babyId;
    return bid != null &&
        _breastTimer.babyId == bid &&
        _breastTimer.side == side &&
        _breastTimer.isRunning;
  }

  Future<void> _persistBreast(
      {required DateTime start,
      required DateTime end,
      required String side}) async {
    final id = _babyId;
    if (id == null) return;
    final sec = end.difference(start).inSeconds;
    if (sec < 1) return;
    final newId = await AppDatabase.instance.insertFeeding(
      babyId: id,
      startedAt: start,
      endedAt: end,
      durationSec: sec,
      side: side,
      type: 'peito',
    );
    FeedingCloudSync.pushLocalSoon(localBabyId: id, localFeedingId: newId);
    await _syncLocalReminders(id);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.of(context).feedingSavedOk)));
    }
    _refreshFeedingsFuture();
  }

  Future<void> _onBreastCircleTap(String side) async {
    final sTxt = S.of(context);
    final bid = _babyId;
    if (bid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(sTxt.feedingSelectBabyFirst)));
      return;
    }

    await _breastTimer.onCircleTap(
      babyId: bid,
      tappedSide: side,
      persistBreast: (
              {required DateTime start,
              required DateTime end,
              required String side}) =>
          _persistBreast(start: start, end: end, side: side),
      snackbarTooShort: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(sTxt.feedingHubTimerTooShort)));
        }
      },
    );
  }

  Future<void> _showManualBreastSheet() async {
    final s = S.of(context);
    final id = _babyId;
    if (id == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.feedingSelectBabyFirst)));
      return;
    }

    var sideSel = (_breastTimer.isRunning && _breastTimer.babyId == id)
        ? (_breastTimer.side ?? 'esquerdo')
        : 'esquerdo';
    var minText = '10';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Theme(
          data: PortalNightUi.cardFormTheme(ctx),
          child: StatefulBuilder(builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 20,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.feedingHubManualTitle,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: minText,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: s.feedingHubManualMinutes,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onChanged: (v) => minText = v,
                  ),
                  const SizedBox(height: 12),
                  CardOptionPickerField<String>(
                    label: s.feedingSideLabel,
                    sheetTitle: s.feedingSideLabel,
                    value: sideSel,
                    options: [
                      CardOption(
                          value: 'esquerdo', label: s.feedingSideLeft),
                      CardOption(
                          value: 'direito', label: s.feedingSideRight),
                    ],
                    onChanged: (v) => setSheet(() => sideSel = v),
                  ),
                const SizedBox(height: 18),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.feedingAlertAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () async {
                    final mins =
                        int.tryParse(minText.trim().replaceAll(',', '')) ?? 0;
                    if (mins <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(s.feedingHubManualInvalid)));
                      return;
                    }
                    final ended = DateTime.now();
                    final started = ended.subtract(Duration(minutes: mins));
                    try {
                      final newId = await AppDatabase.instance.insertFeeding(
                        babyId: id,
                        startedAt: started,
                        endedAt: ended,
                        durationSec: ended.difference(started).inSeconds,
                        side: sideSel,
                        type: 'peito',
                        quantityMl: null,
                        note: null,
                      );
                      FeedingCloudSync.pushLocalSoon(
                          localBabyId: id, localFeedingId: newId);
                      await _syncLocalReminders(id);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.feedingSavedOk)));
                      setState(() => _refreshFeedingsFuture());
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('${s.feedingSaveFail} $e')));
                      }
                    }
                  },
                  child: Text(s.add),
                ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Future<void> _showEditFeedingSheet(S s, FeedingRecord r) async {
    final bid = _babyId;
    if (bid == null) return;

    final type = (r.type ?? '').trim();
    var minText = '${math.max(1, (r.durationSec / 60).ceil())}';
    final q = r.quantityMl;
    var mlText = q == null
        ? ''
        : (q.truncateToDouble() == q
            ? '${q.round()}'
            : '$q'.replaceAll('.', ','));
    var noteText = (r.note ?? '');

    String sideSel = () {
      final raw = (r.side ?? '').trim();
      const ok = {'esquerdo', 'direito', 'ambos'};
      return ok.contains(raw) ? raw : 'esquerdo';
    }();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Theme(
          data: PortalNightUi.cardFormTheme(ctx),
          child: StatefulBuilder(builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 18,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(s.edit,
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (type == 'peito' || type.isEmpty) ...[
                      TextFormField(
                        initialValue: minText,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: s.feedingHubManualMinutes,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14))),
                        onChanged: (v) => minText = v,
                      ),
                      const SizedBox(height: 12),
                      CardOptionPickerField<String>(
                        label: s.feedingSideLabel,
                        sheetTitle: s.feedingSideLabel,
                        value: sideSel,
                        options: [
                          CardOption(
                              value: 'esquerdo', label: s.feedingSideLeft),
                          CardOption(
                              value: 'direito', label: s.feedingSideRight),
                          CardOption(
                              value: 'ambos', label: s.feedingSideBoth),
                        ],
                        onChanged: (v) => setSheet(() => sideSel = v),
                      ),
                    ],
                  if (type == 'mamadeira') ...[
                    TextFormField(
                      initialValue: mlText,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '${s.feedingQty} (${_liquidUnitLabel(s)})',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onChanged: (v) => mlText = v,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: noteText,
                      maxLines: 2,
                      decoration: InputDecoration(
                          labelText: s.feedingNote,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onChanged: (v) => noteText = v,
                    ),
                  ],
                  if (type == 'solidos') ...[
                    TextFormField(
                      initialValue: noteText,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                          labelText: s.feedingHubSolidDescribe,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onChanged: (v) => noteText = v,
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.feedingAlertAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: () async {
                      try {
                        if (type == 'peito' || type.isEmpty) {
                          final mins = int.tryParse(
                                  minText.trim().replaceAll(',', '')) ??
                              0;
                          if (mins <= 0) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text(s.feedingHubManualInvalid)));
                            }
                            return;
                          }
                          final durSec = mins * 60;
                          final newEnd =
                              r.startedAt.add(Duration(seconds: durSec));
                          await AppDatabase.instance.updateFeeding(
                            id: r.id,
                            babyId: bid,
                            startedAt: r.startedAt,
                            endedAt: newEnd,
                            durationSec: durSec,
                            side: sideSel,
                            type: 'peito',
                            quantityMl: null,
                            note: null,
                          );
                          FeedingCloudSync.pushLocalSoon(
                              localBabyId: bid, localFeedingId: r.id);
                        } else if (type == 'mamadeira') {
                          final ml =
                              MeasurementFormat.parseLiquidToMl(mlText) ?? -1;
                          if (ml <= 0) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text(s.feedingHubMlRequired)));
                            }
                            return;
                          }
                          await AppDatabase.instance.updateFeeding(
                            id: r.id,
                            babyId: bid,
                            startedAt: r.startedAt,
                            endedAt: r.endedAt,
                            durationSec: r.durationSec,
                            side: null,
                            type: 'mamadeira',
                            quantityMl: ml,
                            note: noteText.trim().isEmpty
                                ? null
                                : noteText.trim(),
                          );
                          FeedingCloudSync.pushLocalSoon(
                              localBabyId: bid, localFeedingId: r.id);
                        } else if (type == 'solidos') {
                          await AppDatabase.instance.updateFeeding(
                            id: r.id,
                            babyId: bid,
                            startedAt: r.startedAt,
                            endedAt: r.endedAt,
                            durationSec: r.durationSec,
                            side: null,
                            type: 'solidos',
                            quantityMl: null,
                            note: noteText.trim().isEmpty
                                ? null
                                : noteText.trim(),
                          );
                          FeedingCloudSync.pushLocalSoon(
                              localBabyId: bid, localFeedingId: r.id);
                        }

                        await _syncLocalReminders(bid);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(s.feedingHubFeedingUpdatedOk)));
                        setState(() => _refreshFeedingsFuture());
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text('${s.feedingSaveFail} $e')));
                        }
                      }
                    },
                    child: Text(s.edit),
                  ),
                ],
              ),
            ),
          );
          }),
        );
      },
    );
  }

  Future<void> _saveBottle(S s) async {
    final id = _babyId;
    if (id == null) return;
    final ml = MeasurementFormat.parseLiquidToMl(_bottleMlCtrl.text) ?? -1;
    if (ml <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.feedingHubMlRequired)));
      return;
    }
    final now = DateTime.now();
    try {
      final newId = await AppDatabase.instance.insertFeeding(
        babyId: id,
        startedAt: now,
        endedAt: now.add(const Duration(seconds: 1)),
        durationSec: 60,
        side: null,
        type: 'mamadeira',
        quantityMl: ml,
        note: _bottleNoteCtrl.text.trim().isEmpty
            ? null
            : _bottleNoteCtrl.text.trim(),
      );
      FeedingCloudSync.pushLocalSoon(localBabyId: id, localFeedingId: newId);
      await _syncLocalReminders(id);
      _bottleMlCtrl.clear();
      _bottleNoteCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.feedingSavedOk)));
      setState(() => _refreshFeedingsFuture());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${s.feedingSaveFail} $e')));
      }
    }
  }

  Future<void> _saveSolid(S s) async {
    final id = _babyId;
    if (id == null) return;
    final note = _solidNoteCtrl.text.trim();
    final now = DateTime.now();
    try {
      final newId = await AppDatabase.instance.insertFeeding(
        babyId: id,
        startedAt: now,
        endedAt: now.add(const Duration(seconds: 1)),
        durationSec: 1,
        side: null,
        type: 'solidos',
        quantityMl: null,
        note: note.isEmpty ? null : note,
      );
      FeedingCloudSync.pushLocalSoon(localBabyId: id, localFeedingId: newId);
      await _syncLocalReminders(id);
      _solidNoteCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.feedingSavedOk)));
      setState(() => _refreshFeedingsFuture());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${s.feedingSaveFail} $e')));
      }
    }
  }

  String _typeBadge(S s, FeedingRecord r) {
    switch ((r.type ?? '').trim()) {
      case 'mamadeira':
        return s.feedingTypeBottle;
      case 'solidos':
        return s.feedingTypeSolid;
      default:
        return s.feedingTypeBreast;
    }
  }

  Future<void> _confirmAndDeleteFeeding(S s, FeedingRecord r) async {
    final bid = _babyId;
    if (bid == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(s.delete),
          content: Text(s.confirmDelete),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(s.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(s.delete),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;

    try {
      final cloudId = await AppDatabase.instance
          .getRowCloudId(table: 'feedings', id: r.id, babyId: bid);
      await AppDatabase.instance.deleteFeeding(id: r.id, babyId: bid);
      await _syncLocalReminders(bid);
      if (cloudId != null) {
        try {
          await FirestoreService.instance.deleteEvent(cloudId);
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.deletedOk)));
      _refreshFeedingsFuture();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${s.deleteFail} $e')));
    }
  }

  String _sideUi(S s, String? raw) {
    switch ((raw ?? '').trim()) {
      case 'esquerdo':
        return s.feedingSideLeft;
      case 'direito':
        return s.feedingSideRight;
      case 'ambos':
        return s.feedingSideBoth;
      default:
        return '';
    }
  }

  String _recordSubtitle(S s, FeedingRecord r) {
    if (r.type == 'mamadeira') {
      final q = r.quantityMl;
      return q == null ? '—' : MeasurementFormat.liquid(q);
    }
    if (r.type == 'solidos') {
      return r.note ?? '—';
    }
    final side = _sideUi(s, r.side);
    final m = Duration(seconds: r.durationSec).inMinutes;
    return side.isEmpty ? '$m min' : '$m min · $side';
  }

  String _liquidUnitLabel(S s) {
    return switch (MeasurementUnitsPrefs.liquid.value) {
      LiquidUnit.ml => s.unitsOptMl,
      LiquidUnit.ukFloz => s.unitsOptUkFloz,
      LiquidUnit.usFloz => s.unitsOptUsFloz,
    };
  }

  String _fmtLineTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _circleButton({
    required VoidCallback onTap,
    required String letter,
    required bool active,
    required Color sideColor,
  }) {
    final borderInactive =
        Border.all(color: sideColor.withAlpha(150), width: 2.2);
    final borderActive = Border.all(color: sideColor, width: 4.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 118,
          height: 118,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? sideColor.withAlpha(52) : Colors.white,
            border: active ? borderActive : borderInactive,
            boxShadow: active
                ? [
                    BoxShadow(
                        color: sideColor.withAlpha(115),
                        blurRadius: 22,
                        spreadRadius: 2,
                        offset: const Offset(0, 10)),
                  ]
                : null,
          ),
          child: Text(
            letter,
            style: TextStyle(
              fontSize: active ? 36 : 32,
              fontWeight: FontWeight.w900,
              color:
                  active ? sideColor.withAlpha(250) : sideColor.withAlpha(195),
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _breastUsagePie(S s, List<FeedingRecord> all) {
    final breast = all.where((r) => (r.type ?? '').trim() == 'peito').toList();
    double left = 0;
    double right = 0;
    for (final r in breast) {
      final sec = r.durationSec <= 0 ? 0 : r.durationSec;
      final side = (r.side ?? '').trim();
      if (side == 'direito') {
        right += sec;
      } else if (side == 'esquerdo') {
        left += sec;
      }
    }
    final total = left + right;
    if (total <= 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          s.feedingHubBreastPieEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black.withAlpha(140)),
        ),
      );
    }

    final leftPct = (left / total) * 100.0;
    final rightPct = (right / total) * 100.0;

    final totalBreastDur = Duration(seconds: total.round());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          s.feedingHubBreastPieTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black.withAlpha(170),
              fontSize: 15),
        ),
        const SizedBox(height: 14),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withAlpha(14)),
            boxShadow: [
              BoxShadow(
                color: _pieBreastLeft.withAlpha(28),
                blurRadius: 18,
                offset: const Offset(-4, 8),
              ),
              BoxShadow(
                color: _pieBreastRight.withAlpha(26),
                blurRadius: 18,
                offset: const Offset(4, 8),
              ),
            ],
          ),
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // fl_chart usa o rect inteiro do pai; caixa alta + pouca altura fazia overflow.
                const maxPieSide = 280.0;

                /// Diâmetro exterior ≈ `2 * (holeR + ringR)`; margem para `%` nos arcos.
                const baseHoleR = 52.0;
                const baseRingR = 62.0;
                const minSide = baseHoleR * 2 + baseRingR * 2 + 8;
                final side = math.min(constraints.maxWidth, maxPieSide);
                final scale = side >= minSide ? 1.0 : side / minSide;
                final holeR = baseHoleR * scale;
                final ringR = baseRingR * scale;
                final divider = BorderSide(
                  color: _pieSectionDivider.color,
                  width: _pieSectionDivider.width * scale,
                );
                return SizedBox(
                  width: side,
                  height: side,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      PieChart(
                        PieChartData(
                          centerSpaceRadius: holeR,
                          sectionsSpace: 0,
                          sections: [
                            PieChartSectionData(
                              value: left,
                              color: _pieBreastLeft,
                              radius: ringR,
                              borderSide: divider,
                              title: '${leftPct.round()}%',
                              titleStyle: _pieArcTitleStyle.copyWith(
                                  fontSize: 15 * scale),
                              titlePositionPercentageOffset: 0.6,
                            ),
                            PieChartSectionData(
                              value: right,
                              color: _pieBreastRight,
                              radius: ringR,
                              borderSide: divider,
                              title: '${rightPct.round()}%',
                              titleStyle: _pieArcTitleStyle.copyWith(
                                  fontSize: 15 * scale),
                              titlePositionPercentageOffset: 0.6,
                            ),
                          ],
                        ),
                      ),
                      IgnorePointer(
                        child: SizedBox(
                          width: 88,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _fmtDurationShort(totalBreastDur),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: Colors.black.withAlpha(215),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                s.feedingTypeBreast,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black.withAlpha(115),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 8,
          children: [
            _LegendDot(
                color: _pieBreastLeft,
                label:
                    '${s.feedingSideLeft}: ${_fmtDurationShort(Duration(seconds: left.round()))}'),
            _LegendDot(
                color: _pieBreastRight,
                label:
                    '${s.feedingSideRight}: ${_fmtDurationShort(Duration(seconds: right.round()))}'),
          ],
        ),
      ],
    );
  }

  Widget _breastCard(S s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
      decoration: BoxDecoration(
        color: _breastCardBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.feedingHubTapSidesHint,
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.black.withAlpha(150), height: 1.35)),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  _circleButton(
                    onTap: () => _onBreastCircleTap('esquerdo'),
                    letter: s.feedingHubLetterLeft,
                    active: _breastCircleActive('esquerdo'),
                    sideColor: _pieBreastLeft,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _fmtHms(_elapsedBreastDisplay('esquerdo')),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2),
                  ),
                ],
              ),
              Column(
                children: [
                  _circleButton(
                    onTap: () => _onBreastCircleTap('direito'),
                    letter: s.feedingHubLetterRight,
                    active: _breastCircleActive('direito'),
                    sideColor: _pieBreastRight,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _fmtHms(_elapsedBreastDisplay('direito')),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.feedingAlertAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: _showManualBreastSheet,
              child: Text(s.feedingHubAddManualEntry.toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            ),
          ),
          FutureBuilder<List<Map<String, Object?>>>(
            future: _feedingsFuture,
            builder: (context, snap) {
              final rows = snap.data ?? const [];
              final all = rows.map(FeedingRecord.fromRow).toList();
              return _breastUsagePie(s, all);
            },
          ),
        ],
      ),
    );
  }

  Widget _bottleCard(S s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
          color: _bottleCardBg, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _bottleMlCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '${s.feedingQty} (${_liquidUnitLabel(s)})',
              prefixIcon: const Icon(Icons.local_drink_outlined),
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _bottleNoteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: s.feedingNote,
              prefixIcon: const Icon(Icons.notes_outlined),
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.feedingAlertAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => _saveBottle(s),
            child: Text(s.feedingHubSaveBottle.toUpperCase(),
                style: const TextStyle(
                    fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _solidsCard(S s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
          color: _solidsCardBg, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _solidNoteCtrl,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: s.feedingHubSolidDescribe,
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.feedingAlertAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => _saveSolid(s),
            child: Text(s.feedingHubSaveSolid.toUpperCase(),
                style: const TextStyle(
                    fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _overviewBlock(S s, {required GlobalKey resultsKey}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: Material(
            color: AppTheme.feedingAlertAccent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                final willExpand = !_overviewExpanded;
                setState(() {
                  _overviewExpanded = willExpand;
                  _feedingHistoryVisible = _historyPageSize;
                });
                if (willExpand) {
                  _scrollOverviewResultsIntoView(resultsKey);
                }
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      s.feedingHubOverviewTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          height: 1.25),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                        _overviewExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeOut,
          sizeCurve: Curves.easeOut,
          crossFadeState: _overviewExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Container(
            key: resultsKey,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: _overviewFeedingsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final rows = snap.data ?? [];
                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(s.feedingHubOverviewEmpty,
                        style: TextStyle(color: Colors.black.withAlpha(140))),
                  );
                }
                final recs = rows
                    .map(FeedingRecord.fromRow)
                    .take(_feedingHistoryVisible)
                    .toList();
                return Column(
                  children: [
                    ...recs.map((r) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side:
                                BorderSide(color: Colors.black.withAlpha(18))),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          onTap: () => _showEditFeedingSheet(s, r),
                          title: Text(_typeBadge(s, r),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_recordSubtitle(s, r),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(
                                _fmtLineTime(r.startedAt),
                                style: TextStyle(
                                    color: Colors.black.withAlpha(120),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: s.edit,
                                onPressed: () => _showEditFeedingSheet(s, r),
                                icon: Icon(Icons.edit_outlined,
                                    color: AppTheme.feedingAlertAccent
                                        .withAlpha(200)),
                              ),
                              IconButton(
                                tooltip: s.delete,
                                onPressed: () => _confirmAndDeleteFeeding(s, r),
                                icon: Icon(Icons.delete_outline,
                                    color: Colors.red.withAlpha(190)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (_feedingHistoryVisible < rows.length)
                      TextButton.icon(
                        onPressed: () => setState(
                            () => _feedingHistoryVisible += _historyPageSize),
                        icon: const Icon(Icons.expand_more_rounded),
                        label: Text(s.historyViewMoreButton),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  AppBar _feedingAppBar(String title, bool night) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: night ? PortalTimeOfDay.nightOutlinedTextColor : null,
          shadows: night ? PortalTimeOfDay.nightTextOutlineShadows : null,
        ),
      ),
      iconTheme: night
          ? const IconThemeData(color: PortalTimeOfDay.nightOutlinedTextColor)
          : null,
      actionsIconTheme: night
          ? const IconThemeData(color: PortalTimeOfDay.nightOutlinedTextColor)
          : null,
      foregroundColor:
          night ? PortalTimeOfDay.nightOutlinedTextColor : null,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    );
  }

  TextStyle _feedingNightAlertTextStyle(bool night, {double fontSize = 14}) {
    if (!night) {
      return TextStyle(fontSize: fontSize);
    }
    return TextStyle(
      fontSize: fontSize,
      color: PortalTimeOfDay.nightOutlinedTextColor,
      shadows: PortalTimeOfDay.nightTextOutlineShadows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final id = _babyId;

    return ListenableBuilder(
      listenable: PortalLayoutPrefs.instance,
      builder: (context, _) {
        final night = PortalTimeOfDay.isNight(DateTime.now());
        final tabLabelColor = night
            ? PortalTimeOfDay.nightOutlinedTextColor
            : AppTheme.feedingAlertAccent;
        final tabUnselectedColor = night
            ? PortalTimeOfDay.nightOutlinedTextColor.withAlpha(200)
            : Colors.black.withAlpha(120);
        final tabIndicatorColor = night
            ? PortalTimeOfDay.nightOutlinedTextColor
            : AppTheme.feedingAlertAccent;

        if (id == null) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _feedingAppBar(widget.appBarTitle, night),
            body: SafeArea(
              top: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(s.feedingNoBabyHint, textAlign: TextAlign.center),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _feedingAppBar(widget.appBarTitle, night),
          body: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: Colors.transparent,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: tabLabelColor,
                    unselectedLabelColor: tabUnselectedColor,
                    indicatorColor: tabIndicatorColor,
                    indicatorWeight: 3,
                    tabs: [
                      Tab(text: s.feedingTabBreastfeeding.toUpperCase()),
                      Tab(text: s.feedingTabBottle.toUpperCase()),
                      Tab(text: s.feedingTabSolids.toUpperCase()),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: AndroidExactAlarmCard(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: HomePrefs.feedingAlertsEnabled,
                    builder: (context, enabled, _) {
                      final a = AppTheme.feedingAlertAccent;
                      final alertIconColor = night
                          ? PortalTimeOfDay.nightOutlinedTextColor
                          : a.withAlpha(220);
                      final alertTitleStyle = TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: night
                            ? PortalTimeOfDay.nightOutlinedTextColor
                            : null,
                        shadows: night
                            ? PortalTimeOfDay.nightTextOutlineShadows
                            : null,
                      );
                      final alertBodyStyle = _feedingNightAlertTextStyle(
                        night,
                        fontSize: 12,
                      ).copyWith(height: 1.25);
                      final alertHintStyle = _feedingNightAlertTextStyle(
                        night,
                        fontSize: 11,
                      ).copyWith(height: 1.2);
                      return SwitchTheme(
                        data: AppTheme.switchThemeColored(a),
                        child: SwitchListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          dense: true,
                          secondary: Icon(
                            Icons.notifications_active_outlined,
                            color: alertIconColor,
                          ),
                          title: Text(
                            s.feedingAlertsSwitchTitle,
                            style: alertTitleStyle,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s.feedingAlertsSwitchSubtitle,
                                style: night
                                    ? alertBodyStyle
                                    : alertBodyStyle.copyWith(
                                        color: Colors.black.withAlpha(135),
                                      ),
                              ),
                              if (enabled)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    s.feedingScreenAlertsHint,
                                    style: night
                                        ? alertHintStyle
                                        : alertHintStyle.copyWith(
                                            color: Colors.black.withAlpha(110),
                                          ),
                                  ),
                                ),
                            ],
                          ),
                          value: enabled,
                          activeTrackColor: a.withAlpha(90),
                          onChanged: (v) =>
                              HomePrefs.setFeedingAlertsEnabled(v),
                        ),
                      );
                    },
                  ),
                ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(
                    controller: _breastScrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _breastCard(s),
                        const SizedBox(height: 18),
                        _overviewBlock(s,
                            resultsKey: _overviewResultsKeyBreast),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    controller: _bottleScrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _bottleCard(s),
                        const SizedBox(height: 18),
                        _overviewBlock(s,
                            resultsKey: _overviewResultsKeyBottle),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    controller: _solidsScrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _solidsCard(s),
                        const SizedBox(height: 18),
                        _overviewBlock(s,
                            resultsKey: _overviewResultsKeySolids),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withAlpha(80), blurRadius: 4)
                  ])),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.black.withAlpha(150),
                    fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
