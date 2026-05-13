import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/current_baby_controller.dart';
import '../controllers/sleep_timer_controller.dart';
import '../i18n/app_i18n.dart';
import '../services/app_database.dart';
import '../services/firebase/sleep_cloud_sync.dart';
import '../services/firebase/firestore_service.dart';
import '../services/home_prefs.dart';
import '../services/sleep_routine.dart';

/// Tela de sono: modo idle com “Iniciar sono”; modo ativo com cronómetro, ilustração e gravar ao acordar.
class SleepPage extends StatefulWidget {
  const SleepPage({super.key});

  @override
  State<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends State<SleepPage> {
  static const Color _pink = Color(0xFFFF5C8D);
  static const Color _purple = Color(0xFF9D8AF2);
  static const Color _pageBg = Color(0xFFF5F6F8);

  final _sleepTimer = SleepTimerController.instance;
  final _currentBaby = CurrentBabyController.instance;
  final _noteCtrl = TextEditingController();
  Future<List<Map<String, Object?>>>? _sleepHistoryFuture;
  Future<_RoutineVm>? _routineFuture;

  /// Com o sono parado já não há [SleepTimerController] ticking; esta régua e o próximo sono
  /// dependem da hora actual — atualizamos a cada poucos segundos em modo idle.
  Timer? _idleWakeRoutineTicker;

  ({double markerT, SleepRoutinePhase phase, int nextEstimateMin}) _wakeRoutineDerivedNow(_RoutineVm vm) {
    final last = vm.lastSleepEnd;
    final w = vm.window;
    if (last == null) {
      return (markerT: 0.08, phase: SleepRoutinePhase.early, nextEstimateMin: w.minAwakeMin);
    }
    final now = DateTime.now();
    final awakeMinutes = now.difference(last).inMilliseconds / 60000.0;
    final awakeFloor = awakeMinutes.floor();
    return (
      markerT: SleepRoutine.markerThreeZones(awakeMinutes: awakeMinutes, w: w),
      phase: SleepRoutine.phaseFor(awakeMinutes: awakeFloor, w: w),
      nextEstimateMin: SleepRoutine.estimateNextNapMinutes(awakeMinutes: awakeFloor, w: w),
    );
  }

  void _syncIdleWakeRoutineTicker() {
    final wantTicker = !_sleepTimer.isTracking;
    if (wantTicker && _idleWakeRoutineTicker == null) {
      _idleWakeRoutineTicker = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted && !_sleepTimer.isTracking) setState(() {});
      });
      return;
    }
    if (!wantTicker && _idleWakeRoutineTicker != null) {
      _idleWakeRoutineTicker!.cancel();
      _idleWakeRoutineTicker = null;
    }
  }

  _SleepQuality _qualityForDuration(Duration d) {
    final min = d.inMinutes;
    if (min < 20) return _SleepQuality.bad;
    if (min < 50) return _SleepQuality.ok;
    return _SleepQuality.good;
  }

  @override
  void initState() {
    super.initState();
    _sleepTimer.addListener(_onTick);
    _currentBaby.addListener(_onBaby);
    _reloadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncIdleWakeRoutineTicker();
    });
  }

  void _reloadHistory() {
    final bid = _currentBaby.currentBabyId;
    setState(() {
      _sleepHistoryFuture = bid == null ? null : AppDatabase.instance.listSleepRecords(babyId: bid, limit: 40);
      _routineFuture = bid == null ? null : _loadRoutineVm();
    });
  }

  Future<_RoutineVm> _loadRoutineVm() async {
    final bid = _currentBaby.currentBabyId!;
    final birthRaw = _currentBaby.currentBabyRow?['birth_date'] as String?;
    final birth = DateTime.tryParse(birthRaw ?? '');
    final months = SleepRoutine.monthsOld(birth);
    final window = SleepRoutine.windowForMonths(months);

    final rows = await AppDatabase.instance.listSleepRecords(babyId: bid, limit: 40);
    DateTime? lastEnd;
    if (rows.isNotEmpty) {
      // `listSleepRecords` vem por `ended_at DESC` — a régua de vigília segue sempre o **último**
      // sono terminado (o que acabou de ser gravado), sem filtrar pela duração.
      for (final r in rows) {
        lastEnd = DateTime.tryParse(r['ended_at'] as String? ?? '');
        if (lastEnd != null) break;
      }
    }

    final now = DateTime.now();
    final last = lastEnd;
    final awakeMinutes =
        last == null ? 0.0 : (now.difference(last).inMilliseconds / 60000.0).clamp(0.0, 99999.0);

    final phase = lastEnd == null
        ? SleepRoutinePhase.early
        : SleepRoutine.phaseFor(awakeMinutes: awakeMinutes.floor(), w: window);

    final markerT = lastEnd == null
        ? 0.08
        : SleepRoutine.markerThreeZones(awakeMinutes: awakeMinutes, w: window);

    final nextEst = lastEnd == null
        ? window.minAwakeMin
        : SleepRoutine.estimateNextNapMinutes(awakeMinutes: awakeMinutes.floor(), w: window);

    final todayStart = DateTime(now.year, now.month, now.day);
    final todayRows = rows.where((r) {
      final e = DateTime.tryParse(r['ended_at'] as String? ?? '');
      if (e == null) return false;
      return !e.isBefore(todayStart);
    }).toList();

    var sumSec = 0;
    for (final r in todayRows) {
      sumSec += (r['duration_sec'] as num?)?.toInt() ?? 0;
    }
    final todayNaps = todayRows.length;
    final todayAvgMin = todayNaps == 0 ? 0.0 : sumSec / todayNaps / 60.0;

    final trendLess = todayNaps > 0 && todayAvgMin > 0 && todayAvgMin < 38 && todayNaps < 4;

    return _RoutineVm(
      lastSleepEnd: lastEnd,
      awakeMinutes: awakeMinutes.floor(),
      nextEstimateMin: nextEst,
      phase: phase,
      markerT: markerT,
      window: window,
      ageMonths: months,
      todayNaps: todayNaps,
      todayAvgMin: todayAvgMin.round(),
      trendLessThanUsual: trendLess,
    );
  }

  String _fmtAgoShort(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h\u00A0${m}min';
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    return '${d.inMinutes}min';
  }

  String _sleepingMinLabel(Duration d) => _fmtAgoShort(d);

  String _statusForPhase(S strings, SleepRoutinePhase p) {
    switch (p) {
      case SleepRoutinePhase.early:
        return strings.sleepStatusEarly;
      case SleepRoutinePhase.idealWindow:
        return strings.sleepStatusIdeal;
      case SleepRoutinePhase.overdue:
        return strings.sleepStatusOverdue;
    }
  }

  @override
  void dispose() {
    _idleWakeRoutineTicker?.cancel();
    _sleepTimer.removeListener(_onTick);
    _currentBaby.removeListener(_onBaby);
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onTick() {
    _syncIdleWakeRoutineTicker();
    if (mounted) setState(() {});
  }

  void _onBaby() {
    _sleepTimer.discardIfBabyMismatch(_currentBaby.currentBabyId);
    _reloadHistory();
    if (mounted) setState(() {});
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  String _fmtHms(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${_two(h)}:${_two(m)}:${_two(s)}';
  }

  String _fmtClock(DateTime dt) => '${_two(dt.hour)}:${_two(dt.minute)}';

  String _fmtDurShort(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}min';
    if (d.inMinutes < 1) return '${d.inSeconds} s';
    return '$m min';
  }

  Future<void> _startSleep(S strings) async {
    final bid = _currentBaby.currentBabyId;
    if (bid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.feedingSelectBabyFirst)));
      return;
    }
    _noteCtrl.clear();
    _sleepTimer.begin(babyId: bid);
  }

  Future<void> _wake(S strings) async {
    final bid = _currentBaby.currentBabyId;
    final started = _sleepTimer.startedAt;
    if (bid == null || started == null) return;

    final elapsed = _sleepTimer.effectiveElapsed;
    final sec = elapsed.inSeconds;
    if (sec < 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.feedingHubTimerTooShort)));
      return;
    }

    final ended = DateTime.now();
    final note = _noteCtrl.text.trim();

    try {
      final quality = _qualityForDuration(elapsed);
      final newId = await AppDatabase.instance.insertSleepRecord(
        babyId: bid,
        startedAt: started,
        endedAt: ended,
        durationSec: sec,
        quality: quality.key,
        note: note.isEmpty ? null : note,
      );
      SleepCloudSync.pushLocalSoon(localBabyId: bid, localSleepId: newId);
      _sleepTimer.clearSession();
      _noteCtrl.clear();
      _reloadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.sleepSavedOk)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${strings.feedingSaveFail} $e')));
    }
  }

  Future<void> _confirmCancelSession(S strings) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.sleepConfirmCancelSessionTitle),
        content: Text(strings.sleepConfirmCancelSessionBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(strings.sleepCancelSession)),
        ],
      ),
    );
    if (ok == true && mounted) {
      _sleepTimer.clearSession();
      _noteCtrl.clear();
      setState(() {});
    }
  }

  Future<void> _handleBack(S strings) async {
    if (!_sleepTimer.isTracking) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.sleepConfirmBackTitle),
        content: Text(strings.sleepConfirmBackBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(strings.sleepDiscard)),
        ],
      ),
    );
    if (discard == true && mounted) {
      _sleepTimer.clearSession();
      _noteCtrl.clear();
      Navigator.of(context).pop();
    }
  }

  Future<void> _showEditSleep(S strings, Map<String, Object?> row) async {
    final bid = _currentBaby.currentBabyId;
    final id = (row['id'] as num?)?.toInt();
    if (bid == null || id == null) return;

    var started = DateTime.tryParse(row['started_at'] as String? ?? '') ?? DateTime.now();
    var ended = DateTime.tryParse(row['ended_at'] as String? ?? '') ?? DateTime.now();
    final noteCtrl = TextEditingController(text: (row['note'] as String?) ?? '');

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
                  Text(strings.edit, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bedtime_outlined),
                    title: Text(strings.sleepLabelStart),
                    subtitle: Text(
                      '${started.day.toString().padLeft(2, '0')}/${started.month.toString().padLeft(2, '0')}/${started.year} '
                      '${started.hour.toString().padLeft(2, '0')}:${started.minute.toString().padLeft(2, '0')}',
                    ),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: started,
                        firstDate: DateTime(started.year - 3),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (d == null) return;
                      if (!ctx.mounted) return;
                      final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(started));
                      if (t == null) return;
                      setSheet(() {
                        started = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                        if (!ended.isAfter(started)) {
                          ended = started.add(const Duration(minutes: 1));
                        }
                      });
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.wb_sunny_outlined),
                    title: Text(strings.sleepLabelEnd),
                    subtitle: Text(
                      '${ended.day.toString().padLeft(2, '0')}/${ended.month.toString().padLeft(2, '0')}/${ended.year} '
                      '${ended.hour.toString().padLeft(2, '0')}:${ended.minute.toString().padLeft(2, '0')}',
                    ),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: ended,
                        firstDate: DateTime(started.year, started.month, started.day),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (d == null) return;
                      if (!ctx.mounted) return;
                      final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(ended));
                      if (t == null) return;
                      setSheet(() {
                        ended = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                        if (!ended.isAfter(started)) {
                          ended = started.add(const Duration(minutes: 1));
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: strings.sleepObservationsTitle,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _pink, foregroundColor: Colors.white),
                    onPressed: () async {
                      final sec = ended.difference(started).inSeconds;
                      if (sec < 1) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(strings.feedingHubTimerTooShort)));
                        return;
                      }
                      try {
                        final quality = _qualityForDuration(Duration(seconds: sec));
                        await AppDatabase.instance.updateSleepRecord(
                          id: id,
                          babyId: bid,
                          startedAt: started,
                          endedAt: ended,
                          durationSec: sec,
                          quality: quality.key,
                          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                        );
                        SleepCloudSync.pushLocalSoon(localBabyId: bid, localSleepId: id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.sleepUpdatedOk)));
                        _reloadHistory();
                      } catch (e) {
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    },
                    child: Text(strings.saveRecord),
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

  Future<void> _confirmDeleteSleep(S strings, Map<String, Object?> row) async {
    final bid = _currentBaby.currentBabyId;
    final id = (row['id'] as num?)?.toInt();
    if (bid == null || id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.delete),
        content: Text(strings.confirmDelete),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final cloudId = (row['cloud_id'] as String?)?.trim();
      final n = await AppDatabase.instance.deleteSleepRecord(id: id, babyId: bid);
      if (!mounted) return;
      if (n > 0) {
        if (cloudId != null && cloudId.isNotEmpty) {
          try {
            await FirestoreService.instance.deleteEvent(cloudId);
          } catch (_) {}
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.deletedOk)));
        _reloadHistory();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _sleepHistorySection(S strings) {
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(strings.sleepHistoryTitle, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Colors.black.withAlpha(200))),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, Object?>>>(
          future: _sleepHistoryFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
            }
            final rows = snap.data ?? const [];
            if (rows.isEmpty) {
              return Text(strings.sleepHistoryEmpty, style: TextStyle(color: Colors.black.withAlpha(130)));
            }

            final todayRows = rows.where((row) {
              final e = DateTime.tryParse(row['ended_at'] as String? ?? '');
              return e != null && !e.isBefore(todayStart);
            }).toList();

            final older = rows.where((row) {
              final e = DateTime.tryParse(row['ended_at'] as String? ?? '');
              return e == null || e.isBefore(todayStart);
            }).toList();

            Widget rowTile(Map<String, Object?> row) {
              final id = (row['id'] as num?)?.toInt();
              final started = DateTime.tryParse(row['started_at'] as String? ?? '');
              final ended = DateTime.tryParse(row['ended_at'] as String? ?? '');
              final sec = (row['duration_sec'] as num?)?.toInt() ?? 0;
              final dur = Duration(seconds: sec < 0 ? 0 : sec);
              final line = started != null && ended != null
                  ? '${_fmtClock(started)} – ${_fmtClock(ended)} (${_fmtDurShort(dur)})'
                  : _fmtDurShort(dur);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.black.withAlpha(14))),
                  child: ListTile(
                    title: Text(line, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    trailing: id == null
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: strings.edit,
                                onPressed: () => _showEditSleep(strings, row),
                                icon: Icon(Icons.edit_outlined, color: _purple.withAlpha(230)),
                              ),
                              IconButton(
                                tooltip: strings.delete,
                                onPressed: () => _confirmDeleteSleep(strings, row),
                                icon: Icon(Icons.delete_outline, color: Colors.red.withAlpha(200)),
                              ),
                            ],
                          ),
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (todayRows.isNotEmpty) ...[
                  Text(strings.sleepHistoryToday, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _purple.withAlpha(220))),
                  const SizedBox(height: 8),
                  ...todayRows.map(rowTile),
                  if (older.isNotEmpty) const SizedBox(height: 14),
                ],
                if (older.isNotEmpty) ...[
                  Text(strings.recordsTitle, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black.withAlpha(140))),
                  const SizedBox(height: 8),
                  ...older.take(12).map(rowTile),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = S.of(context);
    final bid = _currentBaby.currentBabyId;

    if (bid == null) {
      _idleWakeRoutineTicker?.cancel();
      _idleWakeRoutineTicker = null;
      return Scaffold(
        appBar: AppBar(title: Text(strings.sleepAppBar)),
        body: SafeArea(
          child: Center(
            child: Padding(padding: const EdgeInsets.all(24), child: Text(strings.feedingNoBabyHint, textAlign: TextAlign.center)),
          ),
        ),
      );
    }

    _syncIdleWakeRoutineTicker();

    final tracking = _sleepTimer.isTracking;
    final started = _sleepTimer.startedAt;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black.withAlpha(200)),
          onPressed: () => _handleBack(strings),
        ),
        title: tracking && started != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strings.sleepSessionTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 2),
                  Text(
                    strings.sleepSessionStartedAt(_fmtClock(started)),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black.withAlpha(140)),
                  ),
                ],
              )
            : Text(strings.sleepAppBar, style: const TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: tracking ? _buildActive(context, strings, started!) : _buildIdle(context, strings),
      ),
    );
  }

  Widget _buildIdle(BuildContext context, S strings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<_RoutineVm>(
            future: _routineFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              final vm = snap.data;
              if (vm == null) {
                return const SizedBox.shrink();
              }
              final live = _wakeRoutineDerivedNow(vm);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SleepIdleHero(strings: strings),
                  const SizedBox(height: 16),
                  _SleepRoutineHeaderCard(
                    strings: strings,
                    vm: vm,
                    wakePhase: live.phase,
                    nextTail: _nextCochiloTail(strings, vm, wakePhase: live.phase, nextEstimateMin: live.nextEstimateMin),
                    fmtAgo: _fmtAgoShort,
                    statusLine: _statusForPhase,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _pink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _startSleep(strings),
                    child: Text(strings.sleepStartButton, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    strings.sleepIdealForAge,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _purple.withAlpha(235)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('👶 ', style: TextStyle(fontSize: 14, color: Colors.black.withAlpha(180))),
                      Expanded(
                        child: Text(
                          strings.sleepAgeMonthsLabel(vm.ageMonths),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black.withAlpha(200)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('⏱️ ', style: TextStyle(fontSize: 14, color: Colors.black.withAlpha(180))),
                      Text(
                        strings.sleepWindowMinMax(vm.window.minAwakeMin, vm.window.maxAwakeMin),
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Colors.black.withAlpha(210)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SleepWindowBar(strings: strings, markerT: live.markerT, purple: _purple),
                  const SizedBox(height: 8),
                  Text(
                    strings.sleepWakeWindowExplainer,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black.withAlpha(135)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: Text(strings.sleepLegendG, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black.withAlpha(150)))),
                      Expanded(child: Text(strings.sleepLegendY, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black.withAlpha(150)))),
                      Expanded(child: Text(strings.sleepLegendR, textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black.withAlpha(150)))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sleepHistorySection(strings),
                  const SizedBox(height: 18),
                  _SleepInsightsCard(strings: strings, vm: vm),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: HomePrefs.sleepAlertsEnabled,
                    builder: (context, enabled, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(Icons.notifications_active_outlined, color: _purple.withAlpha(220)),
                        title: Text(strings.sleepToggleAlerts, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        value: enabled,
                        activeThumbColor: _purple,
                        onChanged: (v) => HomePrefs.setSleepAlertsEnabled(v),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _nextCochiloTail(S strings, _RoutineVm vm,
      {SleepRoutinePhase? wakePhase, int? nextEstimateMin}) {
    if (vm.lastSleepEnd == null) return strings.sleepNextApproxMin(vm.window.minAwakeMin);
    final phase = wakePhase ?? vm.phase;
    final next = nextEstimateMin ?? vm.nextEstimateMin;
    if (phase == SleepRoutinePhase.overdue || next <= 0) return strings.sleepRoutineNextNow;
    return strings.sleepNextApproxMin(next);
  }

  Widget _buildActive(BuildContext context, S strings, DateTime started) {
    final elapsed = _sleepTimer.effectiveElapsed;
    final paused = _sleepTimer.isPaused;
    final quality = _qualityForDuration(elapsed);

    return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SleepActiveContextBanner(strings: strings, purple: _purple),
                    const SizedBox(height: 16),
                    Text(
                      strings.sleepSleepingFor(_sleepingMinLabel(elapsed)),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _fmtHms(elapsed),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.black.withAlpha(210)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      paused ? strings.sleepStatusPaused : strings.sleepStatusSleeping,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black.withAlpha(130)),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/sleep/baby_sleep.png',
                        height: 200,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => Icon(Icons.nightlight_round, size: 100, color: _purple.withAlpha(160)),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _pink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: paused ? null : () => _wake(strings),
                      child: Text(strings.sleepFinalizeButton, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 22),
                    _whiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(strings.sleepThisCardTitle, style: const TextStyle(fontWeight: FontWeight.w900, color: _purple, fontSize: 13)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _metricCol(strings.sleepLabelStart, _fmtClock(started))),
                              Container(width: 1, height: 46, color: Colors.black.withAlpha(22)),
                              Expanded(child: _metricCol(strings.sleepLabelDuration, _fmtDurShort(elapsed))),
                              Container(width: 1, height: 46, color: Colors.black.withAlpha(22)),
                              Expanded(child: _metricCol(strings.sleepLabelQuality, quality.emoji, large: true)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _whiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(strings.sleepObservationsTitle, style: const TextStyle(fontWeight: FontWeight.w900, color: _purple, fontSize: 13)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _noteCtrl,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: strings.sleepObservationHint,
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.black.withAlpha(26))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.black.withAlpha(26))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _purple, width: 1.4)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    ValueListenableBuilder<bool>(
                      valueListenable: HomePrefs.sleepAlertsEnabled,
                      builder: (context, enabled, _) {
                        return SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(Icons.notifications_active_outlined, color: _purple.withAlpha(220)),
                          title: Text(strings.sleepToggleAlerts, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          value: enabled,
                          activeThumbColor: _purple,
                          onChanged: (v) => HomePrefs.setSleepAlertsEnabled(v),
                        );
                      },
                    ),
                    _sleepHistorySection(strings),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _roundBarAction(
                    label: paused ? strings.sleepResume : strings.sleepPause,
                    icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    iconColor: _purple,
                    borderColor: Colors.black.withAlpha(35),
                    onTap: () {
                      if (paused) {
                        _sleepTimer.resume();
                      } else {
                        _sleepTimer.pause();
                      }
                    },
                  ),
                  _roundBarAction(
                    label: strings.sleepCancelSession,
                    icon: Icons.stop_rounded,
                    iconColor: Colors.red.shade400,
                    borderColor: Colors.red.withAlpha(160),
                    onTap: () => _confirmCancelSession(strings),
                  ),
                ],
              ),
            ),
          ],
        );
  }

  Widget _metricCol(String label, String value, {bool large = false}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black.withAlpha(120))),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: large ? 26 : 15),
        ),
      ],
    );
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withAlpha(14)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }

  Widget _roundBarAction({
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor, width: 2)),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 108,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black.withAlpha(160)),
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class _RoutineVm {
  final DateTime? lastSleepEnd;
  final int awakeMinutes;
  final int nextEstimateMin;
  final SleepRoutinePhase phase;
  final double markerT;
  final SleepWindowRow window;
  final int ageMonths;
  final int todayNaps;
  final int todayAvgMin;
  final bool trendLessThanUsual;

  const _RoutineVm({
    required this.lastSleepEnd,
    required this.awakeMinutes,
    required this.nextEstimateMin,
    required this.phase,
    required this.markerT,
    required this.window,
    required this.ageMonths,
    required this.todayNaps,
    required this.todayAvgMin,
    required this.trendLessThanUsual,
  });
}

/// Ilustração e texto quando o bebê está acordado (antes de iniciar o registo de sono).
class _SleepIdleHero extends StatelessWidget {
  final S strings;

  const _SleepIdleHero({required this.strings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        // Sem "fundo preto": deixa a ilustração respirar como um card normal.
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(45), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/sleep/baby_awake.png',
              height: 152,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => Icon(Icons.wb_sunny_rounded, size: 80, color: Colors.amber.withAlpha(200)),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5C8D).withAlpha(230),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              strings.sleepHeroAwakeBadge,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            strings.sleepHeroAwakeCaption,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withAlpha(170),
              height: 1.45,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lembrete no topo da sessão ativa: está a dormir — use Terminar sono ao acordar.
class _SleepActiveContextBanner extends StatelessWidget {
  final S strings;
  final Color purple;

  const _SleepActiveContextBanner({required this.strings, required this.purple});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: purple.withAlpha(36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: purple.withAlpha(100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.nightlight_round, color: purple.withAlpha(240), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.sleepHeroSleepingBadge,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black.withAlpha(220)),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.sleepHeroSleepingCaption,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.35, color: Colors.black.withAlpha(150)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepRoutineHeaderCard extends StatelessWidget {
  final S strings;
  final _RoutineVm vm;
  final SleepRoutinePhase wakePhase;
  final String nextTail;
  final String Function(Duration) fmtAgo;
  final String Function(S, SleepRoutinePhase) statusLine;

  const _SleepRoutineHeaderCard({
    required this.strings,
    required this.vm,
    required this.wakePhase,
    required this.nextTail,
    required this.fmtAgo,
    required this.statusLine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withAlpha(18)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 22, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.sleepRoutineCardTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 10),
          Text(
            strings.sleepRoutineVigilHighlight(vm.window.minAwakeMin, vm.window.maxAwakeMin),
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              height: 1.35,
              color: const Color(0xFF5B6B8C),
            ),
          ),
          const SizedBox(height: 14),
          if (vm.lastSleepEnd != null)
            Text(
              strings.sleepRoutineLastLabel(fmtAgo(DateTime.now().difference(vm.lastSleepEnd!))),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.35, color: Colors.black.withAlpha(215)),
            )
          else
            Text(strings.sleepRoutineLastNever, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black.withAlpha(160))),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${strings.sleepRoutineNextPrefix} ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black.withAlpha(220)),
              ),
              Expanded(
                child: Text(
                  nextTail,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF5B6B8C)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            strings.sleepRoutineStatusLine(statusLine(strings, wakePhase)),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _SleepInsightsCard extends StatelessWidget {
  final S strings;
  final _RoutineVm vm;

  const _SleepInsightsCard({required this.strings, required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withAlpha(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.sleepInsightTitle, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black.withAlpha(150))),
          const SizedBox(height: 10),
          Text(strings.sleepInsightNaps(vm.todayNaps), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          if (vm.todayNaps > 0) ...[
            const SizedBox(height: 6),
            Text(strings.sleepInsightAvg(vm.todayAvgMin), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black.withAlpha(190))),
          ],
          const SizedBox(height: 10),
          Text(
            vm.trendLessThanUsual ? strings.sleepInsightTrendDown : strings.sleepInsightTrendOk,
            style: TextStyle(height: 1.4, fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black.withAlpha(175)),
          ),
        ],
      ),
    );
  }
}

class _SleepWindowBar extends StatelessWidget {
  final S strings;
  final double markerT;
  final Color purple;

  const _SleepWindowBar({
    required this.strings,
    required this.markerT,
    required this.purple,
  });

  static const double _barHeight = 46;
  static const double _knobSize = 30;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cx = (w * markerT).clamp(_knobSize / 2, w - _knobSize / 2);
            final knobLeft = cx - _knobSize / 2;

            return SizedBox(
              height: 88,
              width: w,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topLeft,
                children: [
                  // Marcador (nuvem / “agora”) — acima da barra
                  Positioned(
                    left: knobLeft,
                    top: 0,
                    width: _knobSize,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: _knobSize,
                          height: _knobSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: purple, width: 2.5),
                            boxShadow: [
                              BoxShadow(color: purple.withAlpha(55), blurRadius: 12, offset: const Offset(0, 4)),
                              BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.bedtime_rounded, size: 15, color: purple.withAlpha(240)),
                        ),
                        CustomPaint(
                          size: const Size(14, 8),
                          painter: _SleepMarkerDartPainter(color: purple.withAlpha(200)),
                        ),
                      ],
                    ),
                  ),
                  // Três zonas: verde | amarelo | vermelho
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 34,
                    height: _barHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(23),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(color: purple.withAlpha(40), blurRadius: 20, offset: const Offset(0, 8)),
                          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(21),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    color: const Color(0xFFFFE28A),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFF9FD9B5), Color(0xFFC8EED4)],
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFFFF9A8E), Color(0xFFFFC6C0)],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            CustomPaint(painter: _SleepBarGroovePainter()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                children: [
                                  Expanded(child: _zoneLabel('🟡', TextAlign.left)),
                                  Expanded(child: _zoneLabel('🟢', TextAlign.center)),
                                  Expanded(child: _zoneLabel('🔴', TextAlign.right)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _zoneLabel(String text, TextAlign align) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        textAlign: align,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10.5,
          height: 1.15,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.15,
          color: Color(0xDD3A3548),
          shadows: [Shadow(color: Color(0x66FFFFFF), blurRadius: 0, offset: Offset(0, 0.5))],
        ),
      ),
    );
  }
}

/// Linhas verticais suaves entre zonas (como no layout de referência).
class _SleepBarGroovePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final x1 = size.width / 3;
    final x2 = size.width * 2 / 3;
    final highlight = Paint()
      ..color = Colors.white.withAlpha(200)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final shadow = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    for (final x in [x1, x2]) {
      canvas.drawLine(Offset(x + 0.5, 10), Offset(x + 0.5, size.height - 10), shadow);
      canvas.drawLine(Offset(x, 10), Offset(x, size.height - 10), highlight);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pequeno “pico” ligando o marcador à barra.
class _SleepMarkerDartPainter extends CustomPainter {
  final Color color;

  _SleepMarkerDartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SleepMarkerDartPainter oldDelegate) => oldDelegate.color != color;
}

enum _SleepQuality {
  bad('bad', '😫'),
  ok('ok', '😐'),
  good('good', '😊');

  final String key;
  final String emoji;
  const _SleepQuality(this.key, this.emoji);
}
