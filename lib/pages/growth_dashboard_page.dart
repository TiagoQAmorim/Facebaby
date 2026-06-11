import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/app_date_picker.dart';
import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../services/app_database.dart';
import '../services/firebase/growth_cloud_sync.dart';
import '../services/firebase/firestore_service.dart';
import '../services/growth_events.dart';
import '../services/home_prefs.dart';
import '../services/measurement_units_prefs.dart';
import '../services/portal_layout_prefs.dart';
import '../utils/measurement_format.dart';
import '../utils/portal_night_ui.dart';
import '../utils/portal_time_of_day.dart';
import '../data/growth_curves.dart';
import '../services/growth_insights_service.dart';
import '../utils/growth_baseline.dart';
import '../utils/growth_measurements_builder.dart';
import '../services/firebase/profile_cloud_sync.dart';
import '../widgets/growth_chart_widget.dart';
import '../widgets/growth_ruler_picker.dart';

/// Converte kg → valor mostrado na régua conforme preferência de peso.
double _growthWeightDisplayFromKg(double kg) {
  switch (MeasurementUnitsPrefs.weight.value) {
    case WeightUnit.kg:
      return kg;
    case WeightUnit.lb:
      return kg * 2.2046226218;
    case WeightUnit.st:
      return (kg * 2.2046226218) / 14.0;
  }
}

/// Converte valor da régua → kg.
double _growthWeightKgFromDisplay(double v) {
  switch (MeasurementUnitsPrefs.weight.value) {
    case WeightUnit.kg:
      return v;
    case WeightUnit.lb:
      return v / 2.2046226218;
    case WeightUnit.st:
      return (v * 14.0) / 2.2046226218;
  }
}

String _growthWeightUnitChipLabel(WeightUnit u) => switch (u) {
      WeightUnit.kg => 'Kg',
      WeightUnit.lb => 'Lb',
      WeightUnit.st => 'St',
    };

/// Converte cm → valor mostrado na régua (cm ou polegadas).
double _growthLengthDisplayFromCm(double cm) =>
    MeasurementUnitsPrefs.length.value == LengthUnit.inch ? cm / 2.54 : cm;

/// Converte valor da régua → cm.
double _growthLengthCmFromDisplay(double v) =>
    MeasurementUnitsPrefs.length.value == LengthUnit.inch ? v * 2.54 : v;

/// Régua de peso/altura (mesmo padrão do onboarding) para o portal.
Widget _buildPortalGrowthRuler({
  required BuildContext context,
  required S s,
  required String kind,
  required String label,
  required double baseValue,
  required ValueChanged<double> onBaseChanged,
  VoidCallback? onAfterUnitChange,
  String? subjectLabel,
  bool snapStartToZeroWhenAtMax = false,
}) {
  assert(kind == 'weight' || kind == 'height');
  final dragHint = s.onb('DragToAdjust');
  if (kind == 'weight') {
    final wu = MeasurementUnitsPrefs.weight.value;
    final (double max, int divisions, int dec, String unitStr) = switch (wu) {
      WeightUnit.kg => (40.0, 200, 2, 'Kg'),
      WeightUnit.lb => (88.0, 176, 1, 'Lb'),
      WeightUnit.st => (6.3, 126, 2, 'St'),
    };
    return GrowthRulerPicker(
      value: _growthWeightDisplayFromKg(baseValue),
      min: 0,
      max: max,
      divisions: divisions,
      unit: unitStr,
      decimalDigits: dec,
      icon: Icons.monitor_weight_outlined,
      subjectLabel: subjectLabel,
      dragHint: dragHint,
      unitOptions: const ['Kg', 'Lb', 'St'],
      selectedUnit: _growthWeightUnitChipLabel(wu),
      snapStartToZeroWhenAtMax: snapStartToZeroWhenAtMax,
      onUnitSelected: (u) async {
        await MeasurementUnitsPrefs.setWeight(
          u == 'Lb'
              ? WeightUnit.lb
              : u == 'St'
                  ? WeightUnit.st
                  : WeightUnit.kg,
        );
        if (context.mounted) onAfterUnitChange?.call();
      },
      onChanged: (v) => onBaseChanged(_growthWeightKgFromDisplay(v)),
    );
  }
  final lu = MeasurementUnitsPrefs.length.value;
  final inch = lu == LengthUnit.inch;
  return GrowthRulerPicker(
    value: _growthLengthDisplayFromCm(baseValue),
    min: 0,
    max: inch ? 52.0 : 130.0,
    divisions: 260,
    unit: inch ? 'pol' : 'cm',
    decimalDigits: 1,
    icon: Icons.straighten_rounded,
    subjectLabel: subjectLabel,
    dragHint: dragHint,
    unitOptions: const ['cm', 'pol'],
    selectedUnit: inch ? 'pol' : 'cm',
    snapStartToZeroWhenAtMax: snapStartToZeroWhenAtMax,
    onUnitSelected: (u) async {
      await MeasurementUnitsPrefs.setLength(
          u == 'pol' ? LengthUnit.inch : LengthUnit.cm);
      if (context.mounted) onAfterUnitChange?.call();
    },
    onChanged: (v) => onBaseChanged(_growthLengthCmFromDisplay(v)),
  );
}

/// Tabs Peso / Altura / Resumo com cartões Ao nascer · Atual · Mudar e gráfico por métrica.
class GrowthDashboardPage extends StatefulWidget {
  final String appBarTitle;

  const GrowthDashboardPage({super.key, required this.appBarTitle});

  @override
  State<GrowthDashboardPage> createState() => _GrowthDashboardPageState();
}

class _GrowthDashboardPageState extends State<GrowthDashboardPage>
    with SingleTickerProviderStateMixin {
  static const int _historyPageSize = 10;
  static const _accent = Color(0xFF00C4CC);

  /// Só os N registos mais recentes entram na linha do gráfico (por `measured_at`).
  static const _growthChartMaxRecords = 15;

  late final TabController _tabController;
  final _currentBaby = CurrentBabyController.instance;
  final _weightScrollController = ScrollController();
  final _heightScrollController = ScrollController();
  final _summaryScrollController = ScrollController();

  List<Map<String, Object?>> _weight = const [];
  List<Map<String, Object?>> _height = const [];
  bool _loading = false;
  bool _weightHistoryExpanded = false;
  bool _heightHistoryExpanded = false;
  int _weightHistoryVisible = _historyPageSize;
  int _heightHistoryVisible = _historyPageSize;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _currentBaby.addListener(_onBabyChanged);
    _reload();
  }

  @override
  void dispose() {
    _currentBaby.removeListener(_onBabyChanged);
    _weightScrollController.dispose();
    _heightScrollController.dispose();
    _summaryScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onBabyChanged() => _reload();

  Future<void> _reload() async {
    final bid = _currentBaby.currentBabyId;
    if (bid == null) {
      if (mounted) {
        setState(() {
          _weight = const [];
          _height = const [];
          _weightHistoryExpanded = false;
          _heightHistoryExpanded = false;
          _weightHistoryVisible = _historyPageSize;
          _heightHistoryVisible = _historyPageSize;
          _loading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _loading = true);
    final db = AppDatabase.instance;
    final w = await db.listGrowthRecords(babyId: bid, kind: 'weight');
    final h = await db.listGrowthRecords(babyId: bid, kind: 'height');
    if (!mounted) return;
    setState(() {
      _weight = w;
      _height = h;
      _weightHistoryExpanded = false;
      _heightHistoryExpanded = false;
      _weightHistoryVisible = _historyPageSize;
      _heightHistoryVisible = _historyPageSize;
      _loading = false;
    });
  }

  DateTime? _tryParseIso(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _fmtDateDdMmYy(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  String _fmtAxisX(DateTime dt, {required double spanDays}) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    if (spanDays <= 14) return dd;
    if (spanDays <= 90) return '$dd/$mm';
    return '$mm/${(dt.year % 100).toString().padLeft(2, '0')}';
  }

  double? _birthBaseline(String kind, Map<String, Object?>? baby) {
    if (baby == null) return null;
    switch (kind) {
      case 'weight':
        return GrowthBaseline.birthWeightKg(baby);
      case 'height':
        return GrowthBaseline.birthHeightCm(baby);
      default:
        return null;
    }
  }

  double? _latestValue(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return null;
    return (rows.first['value'] as num?)?.toDouble();
  }

  /// Valor inicial da régua ao adicionar peso/altura (último registo → cadastro do bebê).
  double _rulerSeedValueKgOrCm(String kind) {
    final baby = _currentBaby.currentBabyRow;
    switch (kind) {
      case 'weight':
        final latest = _latestValue(_weight);
        if (latest != null && latest > 0) return latest;
        final fromBaby = (baby?['weight_kg'] as num?)?.toDouble();
        if (fromBaby != null && fromBaby > 0) return fromBaby;
        return 0;
      case 'height':
        final latest = _latestValue(_height);
        if (latest != null && latest > 0) return latest;
        final fromBaby = (baby?['height_cm'] as num?)?.toDouble();
        if (fromBaby != null && fromBaby > 0) return fromBaby;
        return 0;
      default:
        return 0;
    }
  }

  String? _latestDateRaw(List<Map<String, Object?>> rows) =>
      rows.isEmpty ? null : rows.first['measured_at'] as String?;

  List<Map<String, Object?>> _asc(List<Map<String, Object?>> rows) {
    final copy = [...rows];
    copy.sort((a, b) {
      final am = a['measured_at'] as String? ?? '';
      final bm = b['measured_at'] as String? ?? '';
      return am.compareTo(bm);
    });
    return copy;
  }

  /// Mais recentes primeiro (lista edição/remoção).
  List<Map<String, Object?>> _desc(List<Map<String, Object?>> rows) {
    final copy = [...rows];
    copy.sort((a, b) {
      final am = a['measured_at'] as String? ?? '';
      final bm = b['measured_at'] as String? ?? '';
      return bm.compareTo(am);
    });
    return copy;
  }

  DateTime _measuredDateTime(Map<String, Object?> row) =>
      _tryParseIso(row['measured_at'] as String?) ?? DateTime.now();

  int? _growthRowId(Map<String, Object?> row) => (row['id'] as num?)?.toInt();

  String _metricShortLabel(S s, String kind) {
    switch (kind) {
      case 'weight':
        return s.labelWeight;
      case 'height':
        return s.labelHeight;
      default:
        return kind;
    }
  }

  String _formatMeasurement(String kind, double? v) {
    if (kind == 'weight') {
      return MeasurementFormat.weight(v, decimalsKg: 2);
    }
    final decimals = kind == 'head' ? 1 : 0;
    return MeasurementFormat.length(v, decimalsCm: decimals);
  }

  String _formatDelta(String kind, double? baseline, double? current) {
    if (baseline == null || current == null) return '—';
    final d = current - baseline;
    final sign = d > 0 ? '+' : (d < 0 ? '' : '');
    if (kind == 'weight') {
      final absStr = MeasurementFormat.weight(d.abs(), decimalsKg: 2);
      return '$sign$absStr';
    }
    final decimals = kind == 'head' ? 1 : 0;
    final absStr = MeasurementFormat.length(d.abs(), decimalsCm: decimals);
    return '$sign$absStr';
  }

  String _displayBabyName(Map<String, Object?>? row, S s) {
    final n = (row?['name'] as String?)?.trim();
    return (n == null || n.isEmpty) ? s.baby : n;
  }

  Future<void> _showAddSheet(S s, String kind) async {
    final bid = _currentBaby.currentBabyId;
    if (bid == null) return;
    final label = _metricShortLabel(s, kind);
    final unit = kind == 'weight'
        ? (switch (MeasurementUnitsPrefs.weight.value) {
            WeightUnit.kg => 'kg',
            WeightUnit.lb => 'lb',
            WeightUnit.st => 'st',
          })
        : (switch (MeasurementUnitsPrefs.length.value) {
            LengthUnit.cm => 'cm',
            LengthUnit.inch => 'pol',
          });
    var rawValue = '';
    var baseValue = (kind == 'weight' || kind == 'height')
        ? _rulerSeedValueKgOrCm(kind)
        : 0.0;
    final babySubject = _displayBabyName(_currentBaby.currentBabyRow, s);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final valueEditor = (kind == 'weight' || kind == 'height')
                ? _buildPortalGrowthRuler(
                    context: ctx,
                    s: s,
                    kind: kind,
                    label: label,
                    baseValue: baseValue,
                    onBaseChanged: (v) => setSheet(() => baseValue = v),
                    onAfterUnitChange: () => setSheet(() {}),
                    subjectLabel: babySubject,
                    snapStartToZeroWhenAtMax: false,
                  )
                : TextField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    onChanged: (v) => setSheet(() => rawValue = v),
                    decoration: InputDecoration(
                      labelText: '$label ($unit)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  );

            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 20,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 22,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(label,
                        style: Theme.of(ctx)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    valueEditor,
                    const SizedBox(height: 18),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        final double? parsed;
                        if (kind == 'weight' || kind == 'height') {
                          parsed = baseValue;
                        } else {
                          parsed = kind == 'weight'
                              ? MeasurementFormat.parseWeightToKg(
                                  rawValue.trim())
                              : MeasurementFormat.parseLengthToCm(
                                  rawValue.trim());
                        }
                        if (parsed == null || parsed <= 0) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text(s.invalidGrowthValue(label))));
                          }
                          return;
                        }
                        final newId = await AppDatabase.instance
                            .insertGrowthRecord(
                                babyId: bid, kind: kind, value: parsed);
                        GrowthCloudSync.pushLocalSoon(
                            localBabyId: bid, localGrowthId: newId);
                        await GrowthBaseline.syncBabyProfileAfterMeasurement(
                          babyId: bid,
                          weightKg: kind == 'weight' ? parsed : null,
                          heightCm: kind == 'height' ? parsed : null,
                        );
                        unawaited(ProfileCloudSync.pushBaby(bid));
                        GrowthEvents.ping();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s.growthSaved(label))));
                        await _reload();
                      },
                      child: Text(s.add),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditGrowthSheet(
      S s, String kind, Map<String, Object?> row) async {
    final bid = _currentBaby.currentBabyId;
    final id = _growthRowId(row);
    if (bid == null || id == null) return;
    final label = _metricShortLabel(s, kind);
    final rowV = (row['value'] as num?)?.toDouble() ?? 0;
    final latestV = _rulerSeedValueKgOrCm(kind);
    final currentV = rowV > 0 ? rowV : latestV;
    final unit = kind == 'weight'
        ? (switch (MeasurementUnitsPrefs.weight.value) {
            WeightUnit.kg => 'kg',
            WeightUnit.lb => 'lb',
            WeightUnit.st => 'st',
          })
        : (switch (MeasurementUnitsPrefs.length.value) {
            LengthUnit.cm => 'cm',
            LengthUnit.inch => 'pol',
          });
    final initialValueText = kind == 'weight'
        ? (switch (MeasurementUnitsPrefs.weight.value) {
            WeightUnit.kg => currentV,
            WeightUnit.lb => currentV * 2.2046226218,
            WeightUnit.st => (currentV * 2.2046226218) / 14.0,
          })
            .toStringAsFixed(2)
            .replaceAll('.', ',')
        : (switch (MeasurementUnitsPrefs.length.value) {
            LengthUnit.cm => currentV,
            LengthUnit.inch => currentV / 2.54,
          })
            .toStringAsFixed(kind == 'head' ? 1 : 0)
            .replaceAll('.', ',');
    final initialMeasured = _measuredDateTime(row);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _EditGrowthSheetBody(
          accent: _accent,
          strings: s,
          kind: kind,
          babyId: bid,
          recordId: id,
          label: label,
          unit: unit,
          rulerInitialBase: currentV,
          initialValueText: initialValueText,
          subjectLabel: _displayBabyName(_currentBaby.currentBabyRow, s),
          initialMeasuredAt: initialMeasured,
          onSaved: () {
            if (!mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(s.growthSaved(label))));
            unawaited(_reload());
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteGrowth(
      S s, String kind, Map<String, Object?> row) async {
    final bid = _currentBaby.currentBabyId;
    final id = _growthRowId(row);
    if (bid == null || id == null) return;
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
      final cloudId = (row['cloud_id'] as String?)?.trim();
      final n =
          await AppDatabase.instance.deleteGrowthRecord(id: id, babyId: bid);
      if (!mounted) return;
      if (n > 0) {
        GrowthEvents.ping();
        if (cloudId != null && cloudId.isNotEmpty) {
          try {
            await FirestoreService.instance.deleteEvent(cloudId);
          } catch (_) {}
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.deletedOk)));
        await _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${s.deleteFail} $e')));
      }
    }
  }

  Widget _growthHistoryList(S s, String kind, List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final label = _metricShortLabel(s, kind);
    final expanded =
        kind == 'weight' ? _weightHistoryExpanded : _heightHistoryExpanded;
    final visibleCount =
        kind == 'weight' ? _weightHistoryVisible : _heightHistoryVisible;
    final items = _desc(rows).take(visibleCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        Text(s.growthHistoryTitle(label),
            style: TextStyle(
                color: Colors.black.withAlpha(150),
                fontWeight: FontWeight.w900,
                fontSize: 14)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            if (kind == 'weight') {
              _weightHistoryExpanded = !_weightHistoryExpanded;
              _weightHistoryVisible = _historyPageSize;
            } else {
              _heightHistoryExpanded = !_heightHistoryExpanded;
              _heightHistoryVisible = _historyPageSize;
            }
          }),
          icon: Icon(
              expanded ? Icons.expand_less_rounded : Icons.history_rounded),
          label: Text(expanded ? s.historyHideButton : s.historyShowButton),
        ),
        if (expanded) ...[
          const SizedBox(height: 10),
          ...items.map((row) {
            final id = _growthRowId(row);
            final dt = _measuredDateTime(row);
            final v = (row['value'] as num?)?.toDouble();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: const Color(0xFFF5F6F8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.black.withAlpha(14))),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: Text(_formatMeasurement(kind, v),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(_fmtDateDdMmYy(dt),
                    style: TextStyle(
                        color: Colors.black.withAlpha(130),
                        fontWeight: FontWeight.w600)),
                trailing: id == null
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: s.edit,
                            onPressed: () => _showEditGrowthSheet(s, kind, row),
                            icon: Icon(Icons.edit_outlined,
                                color: _accent.withAlpha(220)),
                          ),
                          IconButton(
                            tooltip: s.delete,
                            onPressed: () => _confirmDeleteGrowth(s, kind, row),
                            icon: Icon(Icons.delete_outline,
                                color: Colors.red.withAlpha(200)),
                          ),
                        ],
                      ),
              ),
            );
          }),
          if (visibleCount < rows.length)
            TextButton.icon(
              onPressed: () => setState(() {
                if (kind == 'weight') {
                  _weightHistoryVisible += _historyPageSize;
                } else {
                  _heightHistoryVisible += _historyPageSize;
                }
              }),
              icon: const Icon(Icons.expand_more_rounded),
              label: Text(s.historyViewMoreButton),
            ),
        ],
      ],
    );
  }

  String _ctaLabel(S s, int idx) {
    switch (idx) {
      case 0:
        return s.growthAddWeight;
      case 1:
        return s.growthAddHeight;
      default:
        return '';
    }
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required Color titleColor,
    String? subtitle,
  }) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFECEFF1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
              const Divider(height: 14),
              Text(
                value,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.4),
              ),
              if (subtitle != null && subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(subtitle,
                      style: TextStyle(
                          color: titleColor.withAlpha(180), fontSize: 11)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardsRow(String kind, List<Map<String, Object?>> rows, S s) {
    final baby = _currentBaby.currentBabyRow;
    final muted = Colors.black.withAlpha(140);
    final baseline = _birthBaseline(kind, baby);
    final current = _latestValue(rows);
    final birthRaw = baby?['birth_date'] as String?;
    final birthDt = _tryParseIso(birthRaw);
    final birthSub = birthDt == null
        ? (birthRaw?.isNotEmpty == true ? birthRaw! : '')
        : _fmtDateDdMmYy(birthDt);

    final currentRaw = _latestDateRaw(rows);
    final curDt = _tryParseIso(currentRaw);
    final curSub = rows.isEmpty
        ? ''
        : (curDt == null ? (currentRaw ?? '') : _fmtDateDdMmYy(curDt));

    final deltaStr = _formatDelta(kind, baseline, current);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryCard(
            title: s.growthAtBirth,
            subtitle: birthSub.isEmpty ? null : birthSub,
            value: _formatMeasurement(kind, baseline),
            titleColor: muted),
        const SizedBox(width: 8),
        _summaryCard(
            title: s.growthCardCurrent,
            subtitle: curSub.isEmpty ? null : curSub,
            value: _formatMeasurement(kind, current),
            titleColor: muted),
        const SizedBox(width: 8),
        _summaryCard(
            title: s.growthCardChange,
            subtitle: null,
            value: deltaStr,
            titleColor: muted),
      ],
    );
  }

  /// Eixo X = dias desde a meia-noite da data de nascimento (se existir), senão da primeira medição.
  static double _growthXDays(DateTime anchorMidnight, DateTime measured) =>
      measured.difference(anchorMidnight).inMilliseconds /
      Duration.millisecondsPerDay;

  static DateTime _dateOnlyLocal(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  double _growthChartVerticalInterval(double minY, double maxY) {
    final span = math.max(maxY - minY, 1e-6);
    final approx = span / 4;
    if (approx <= 0.05) return 0.05;
    if (approx <= 0.1) return 0.1;
    if (approx <= 0.25) return 0.25;
    if (approx <= 0.5) return 0.5;
    if (approx <= 1) return 1;
    if (approx <= 2) return 2;
    if (approx <= 5) return 5;
    if (approx <= 10) return 10;
    if (approx <= 20) return 20;
    return (approx / 10).ceilToDouble() * 10;
  }

  String _growthAxisYLabel(String kind, double v,
      {required bool deltaMode, required double spanY}) {
    String comma(String s) => s.replaceAll('.', ',');
    if (!deltaMode) {
      if (kind == 'weight') {
        if (spanY >= 2.5) return comma(v.toStringAsFixed(1));
        return comma(v.toStringAsFixed(2));
      }
      if (kind == 'head') {
        if (spanY >= 3) return comma(v.toStringAsFixed(0));
        return comma(v.toStringAsFixed(1));
      }
      // height (cm): sem decimais
      return '${v.round()}';
    }
    if (v == 0) {
      if (kind == 'weight') return comma('0.00');
      if (kind == 'head') return comma('0.0');
      return '0';
    }
    final t = kind == 'weight'
        ? (spanY >= 2.5 ? v.toStringAsFixed(1) : v.toStringAsFixed(2))
        : kind == 'head'
            ? (spanY >= 3 ? v.toStringAsFixed(0) : v.toStringAsFixed(1))
            : v.round().toString();
    final prefix = v > 0 ? '+' : '';
    return prefix + comma(t);
  }

  double _growthChartBottomInterval(double minX, double maxX) {
    final span = math.max(maxX - minX, 1);
    final approx = span / 4;
    if (approx <= 1) return 1;
    if (approx <= 2) return 2;
    if (approx <= 5) return 5;
    if (approx <= 10) return 10;
    if (approx <= 14) return 14;
    return (approx / 7).ceilToDouble() * 7;
  }

  Widget _growthLineChart(
      String kind, List<Map<String, Object?>> rows, String metricTitle) {
    final s = S.of(context);
    final ascFull = _asc(rows);
    if (ascFull.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
            child: Text(s.growthEmpty(metricTitle),
                style: TextStyle(color: Colors.black.withAlpha(140)))),
      );
    }
    final asc = ascFull.length <= _growthChartMaxRecords
        ? ascFull
        : ascFull.sublist(ascFull.length - _growthChartMaxRecords);

    final baby = _currentBaby.currentBabyRow;
    final birthRaw = baby?['birth_date'] as String?;
    final birthDt = _tryParseIso(birthRaw);
    final anchor = birthDt != null
        ? _dateOnlyLocal(birthDt)
        : _dateOnlyLocal(_measuredDateTime(asc.first));

    final b0 = _birthBaseline(kind, baby);
    final deltaMode = (kind == 'weight' || kind == 'height') && b0 != null;
    final double refY = switch ((deltaMode, b0)) {
      (true, final double v) => v,
      _ => 0.0,
    };

    final spots = <FlSpot>[];
    final xLabels = <DateTime>[];
    for (final row in asc) {
      final dt = _measuredDateTime(row);
      final raw = (row['value'] as num?)?.toDouble() ?? 0;
      final y = deltaMode ? (raw - refY) : raw;
      // Eixo X sequencial (0..N-1) para evitar quebra por datas repetidas/mesmo dia.
      spots.add(FlSpot(spots.length.toDouble(), y));
      xLabels.add(dt);
    }

    // Sempre ancorar no valor de cadastro (ao nascer = 0 no eixo Y).
    if (deltaMode) {
      final hasBirthAnchor = spots.isNotEmpty &&
          spots.first.x <= 1e-3 &&
          spots.first.y.abs() <= 1e-6 &&
          _dateOnlyLocal(xLabels.first) == anchor;
      if (!hasBirthAnchor) {
        for (var i = 0; i < spots.length; i++) {
          spots[i] = FlSpot(spots[i].x + 1, spots[i].y);
        }
        spots.insert(0, const FlSpot(0, 0));
        xLabels.insert(0, anchor);
      }
    }

    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    var minSpotX = double.infinity;
    var maxSpotX = double.negativeInfinity;
    for (final p in spots) {
      minSpotX = math.min(minSpotX, p.x);
      maxSpotX = math.max(maxSpotX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }

    if (deltaMode) {
      minY = math.min(minY, 0);
      maxY = math.max(maxY, 0);
    }

    double padSpan;
    if (minY == maxY) {
      padSpan = 1;
      minY -= padSpan * 0.5;
      maxY += padSpan * 0.5;
    } else {
      padSpan = (maxY - minY) * 0.14;
      minY -= padSpan;
      maxY += padSpan;
    }

    final xSpanNatural = math.max(maxSpotX - minSpotX, 0);
    late final double chartMinX;
    late final double chartMaxX;
    if (spots.length <= 1) {
      final mid = maxSpotX;
      final half = math.max(xSpanNatural * 0.5 + 3, 3.5);
      chartMinX = math.max(0, mid - half);
      chartMaxX = mid + half;
    } else {
      final xPad = math.max(xSpanNatural * 0.06, 0.35);
      chartMinX = math.max(0, minSpotX - xPad);
      chartMaxX = maxSpotX + xPad;
    }

    final bottomInterval = _growthChartBottomInterval(chartMinX, chartMaxX);
    final verticalInterval = _growthChartVerticalInterval(minY, maxY);
    final showBottom = spots.length >= 2 || (chartMaxX - chartMinX) >= 1;
    final spanY = maxY - minY;

    // Span real de tempo (em dias) só para decidir quão curto é o label (dd vs dd/mm vs mm/aa).
    final double timeSpanDays = xLabels.length <= 1
        ? 0
        : math.max(
            0.0,
            _growthXDays(
                _dateOnlyLocal(xLabels.first), _dateOnlyLocal(xLabels.last)));

    final leftReserved = deltaMode && kind == 'weight' ? 44.0 : 40.0;

    final chart = AspectRatio(
      aspectRatio: 1.65,
      child: Padding(
        padding: const EdgeInsets.only(right: 8, top: 10),
        child: LineChart(
          LineChartData(
            clipData: const FlClipData.all(),
            minX: chartMinX,
            maxX: chartMaxX,
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              verticalInterval: bottomInterval,
              horizontalInterval: verticalInterval,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: Color(0x22000000), strokeWidth: 1),
              getDrawingVerticalLine: (_) =>
                  const FlLine(color: Color(0x22000000), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: leftReserved,
                  interval: verticalInterval,
                  getTitlesWidget: (v, _) => Text(
                    _growthAxisYLabel(kind, v,
                        deltaMode: deltaMode, spanY: spanY),
                    style: TextStyle(
                        fontSize: 10, color: Colors.black.withAlpha(140)),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: showBottom,
                  interval: bottomInterval,
                  getTitlesWidget: (v, _) {
                    final idx = v.round();
                    if (idx < 0 || idx >= xLabels.length) {
                      return const SizedBox.shrink();
                    }
                    // Evita spam: só mostra quando o tick cai bem perto do inteiro.
                    if ((v - idx).abs() > 0.06) return const SizedBox.shrink();
                    final labelDt = xLabels[idx];
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _fmtAxisX(labelDt, spanDays: timeSpanDays),
                        style: TextStyle(
                            fontSize: 9, color: Colors.black.withAlpha(120)),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                // fl_chart smoothing precisa de ≥3 pontos; com 1–2 a spline pode ficar fora dos limites/clipping.
                isCurved: spots.length >= 3,
                curveSmoothness: 0.35,
                preventCurveOverShooting: spots.length >= 3,
                color: _accent,
                barWidth: 2.8,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [_accent.withAlpha(90), _accent.withAlpha(16)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!deltaMode) return chart;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chart,
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 8),
          child: Text(
            s.growthChartDeltaHint,
            style: TextStyle(
                fontSize: 10, height: 1.25, color: Colors.black.withAlpha(120)),
          ),
        ),
      ],
    );
  }

  Widget _growthCurveSection(S s, GrowthChartMetric metric) {
    final baby = _currentBaby.currentBabyRow;
    final birthRaw = baby?['birth_date'] as String?;
    final birth = DateTime.tryParse(birthRaw ?? '');
    final sexRaw = baby?['sex'] as String?;
    final sx = sexRaw?.trim().toUpperCase();
    final sex = GrowthCurves.sexFromProfile(sexRaw);
    final showSexHint = sx != 'M' && sx != 'F';
    final birthH = GrowthBaseline.birthHeightCm(baby);
    final birthW = GrowthBaseline.birthWeightKg(baby);
    final name = _displayBabyName(baby, s);
    final forWeight = metric == GrowthChartMetric.weight;
    final points = forWeight
        ? GrowthMeasurementsBuilder.weightFromRows(
            birthDate: birth,
            weightRows: _weight,
            birthWeightKg: birthW,
          )
        : GrowthMeasurementsBuilder.heightFromRows(
            birthDate: birth,
            heightRows: _height,
            birthHeightCm: birthH,
          );
    final insightsService = GrowthInsightsService();
    final insights = forWeight
        ? insightsService.buildWeightInsights(
            strings: s,
            babyName: name,
            sex: sex,
            measurements: points,
          )
        : insightsService.buildHeightInsights(
            strings: s,
            babyName: name,
            sex: sex,
            measurements: points,
          );

    return Material(
      color: Colors.white.withAlpha(168),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.black.withAlpha(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              forWeight
                  ? s.growthCurveSectionTitleWeight
                  : s.growthCurveSectionTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 12),
            GrowthChartWidget(
              sex: sex,
              measurements: points,
              strings: s,
              metric: metric,
              showSexHint: showSexHint,
            ),
            if (insights.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...insights.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: Colors.black.withAlpha(200),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricScroll(String kind, List<Map<String, Object?>> rows, S s) {
    final name = _displayBabyName(_currentBaby.currentBabyRow, s);
    final metric = _metricShortLabel(s, kind);
    return SingleChildScrollView(
      controller:
          kind == 'weight' ? _weightScrollController : _heightScrollController,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardsRow(kind, rows, s),
          if (kind == 'height' || kind == 'weight') ...[
            const SizedBox(height: 18),
            _growthCurveSection(
              s,
              kind == 'weight'
                  ? GrowthChartMetric.weight
                  : GrowthChartMetric.height,
            ),
          ],
          const SizedBox(height: 22),
          Text(s.growthChartCaption(name, metric),
              style: TextStyle(
                  color: Colors.black.withAlpha(130),
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _growthLineChart(kind, rows, metric),
          _growthHistoryList(s, kind, rows),
        ],
      ),
    );
  }

  Widget _summaryScroll(S s) {
    final name = _displayBabyName(_currentBaby.currentBabyRow, s);
    return SingleChildScrollView(
      controller: _summaryScrollController,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.growthSummaryIntro,
              style:
                  TextStyle(color: Colors.black.withAlpha(130), height: 1.35)),
          const SizedBox(height: 20),
          Text(s.labelWeight.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _cardsRow('weight', _weight, s),
          const SizedBox(height: 18),
          _growthCurveSection(s, GrowthChartMetric.weight),
          const SizedBox(height: 22),
          Text(s.growthChartCaption(name, s.labelWeight),
              style:
                  TextStyle(color: Colors.black.withAlpha(120), fontSize: 13)),
          _growthLineChart('weight', _weight, s.labelWeight),
          _growthHistoryList(s, 'weight', _weight),
          const SizedBox(height: 28),
          Text(s.labelHeight.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _cardsRow('height', _height, s),
          const SizedBox(height: 18),
          _growthCurveSection(s, GrowthChartMetric.height),
          const SizedBox(height: 22),
          Text(s.growthChartCaption(name, s.labelHeight),
              style:
                  TextStyle(color: Colors.black.withAlpha(120), fontSize: 13)),
          _growthLineChart('height', _height, s.labelHeight),
          _growthHistoryList(s, 'height', _height),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bid = _currentBaby.currentBabyId;

    return ListenableBuilder(
      listenable: PortalLayoutPrefs.instance,
      builder: (context, _) {
        final night = PortalTimeOfDay.isNight(DateTime.now());
        final tabs = PortalNightUi.tabColors(night, dayAccent: _accent);

        if (bid == null) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: PortalNightUi.appBar(widget.appBarTitle, night: night),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child:
                    Text(s.feedingNoBabyHint, textAlign: TextAlign.center),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PortalNightUi.appBar(widget.appBarTitle, night: night),
          body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              labelColor: tabs.label,
              unselectedLabelColor: tabs.unselected,
              indicatorColor: tabs.indicator,
              indicatorWeight: 3,
              tabs: [
                Tab(text: s.growthTabWeight.toUpperCase()),
                Tab(text: s.growthTabHeight.toUpperCase()),
                Tab(text: s.growthTabSummary.toUpperCase()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
            child: ValueListenableBuilder<bool>(
              valueListenable: HomePrefs.growthHealthAlertsEnabled,
              builder: (context, enabled, _) {
                return SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  dense: true,
                  secondary: Icon(
                    Icons.notifications_active_outlined,
                    color: PortalNightUi.alertIconColor(night, _accent),
                  ),
                  title: Text(
                    s.healthGrowthToggleAlerts,
                    style: PortalNightUi.alertTitleStyle(night, fontSize: 14),
                  ),
                  subtitle: Text(
                    s.healthGrowthToggleAlertsSubtitle,
                    style: PortalNightUi.alertSubtitleStyle(night),
                  ),
                  value: enabled,
                  activeThumbColor: _accent,
                  onChanged: (v) => HomePrefs.setGrowthHealthAlertsEnabled(v),
                );
              },
            ),
          ),
          Expanded(
            child: _loading && _weight.isEmpty && _height.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _metricScroll('weight', _weight, s),
                      _metricScroll('height', _height, s),
                      _summaryScroll(s),
                    ],
                  ),
          ),
          if (!_loading && _tabController.index != 2)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 0, 20, 14 + MediaQuery.paddingOf(context).bottom),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  onPressed: () {
                    const kinds = ['weight', 'height'];
                    _showAddSheet(s, kinds[_tabController.index]);
                  },
                  child: Text(
                    _ctaLabel(s, _tabController.index).toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                ),
              ),
            ),
          if (!_loading && _tabController.index == 2)
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
        ],
      ),
        );
      },
    );
  }
}

/// Folha "editar registo": [TextEditingController] só para perímetro cefálico; peso/altura usam [GrowthRulerPicker].
class _EditGrowthSheetBody extends StatefulWidget {
  final Color accent;
  final S strings;
  final String kind;
  final int babyId;
  final int recordId;
  final String label;
  final String unit;
  final double rulerInitialBase;
  final String initialValueText;
  final String subjectLabel;
  final DateTime initialMeasuredAt;
  final VoidCallback onSaved;

  const _EditGrowthSheetBody({
    required this.accent,
    required this.strings,
    required this.kind,
    required this.babyId,
    required this.recordId,
    required this.label,
    required this.unit,
    required this.rulerInitialBase,
    required this.initialValueText,
    required this.subjectLabel,
    required this.initialMeasuredAt,
    required this.onSaved,
  });

  @override
  State<_EditGrowthSheetBody> createState() => _EditGrowthSheetBodyState();
}

class _EditGrowthSheetBodyState extends State<_EditGrowthSheetBody> {
  TextEditingController? _headCtrl;
  late double _rulerBase;
  late DateTime _picked;

  static String _fmtDateDdMmYy(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  @override
  void initState() {
    super.initState();
    _picked = widget.initialMeasuredAt;
    _rulerBase = widget.rulerInitialBase;
    if (widget.kind == 'head') {
      _headCtrl = TextEditingController(text: widget.initialValueText);
    }
  }

  @override
  void dispose() {
    _headCtrl?.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showAppDatePicker(
      context: context,
      initialDate: DateTime(_picked.year, _picked.month, _picked.day),
      firstDate: DateTime(_picked.year - 6),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) {
      setState(() {
        _picked =
            DateTime(d.year, d.month, d.day, _picked.hour, _picked.minute);
      });
    }
  }

  Future<void> _save() async {
    final s = widget.strings;
    final double? parsed = widget.kind == 'head'
        ? MeasurementFormat.parseLengthToCm(_headCtrl!.text.trim())
        : _rulerBase;
    if (parsed == null || parsed <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.invalidGrowthValue(widget.label))));
      }
      return;
    }
    await AppDatabase.instance.updateGrowthRecord(
      id: widget.recordId,
      babyId: widget.babyId,
      value: parsed,
      measuredAt: _picked,
    );
    GrowthCloudSync.pushLocalSoon(
        localBabyId: widget.babyId, localGrowthId: widget.recordId);
    await GrowthBaseline.syncBabyProfileAfterMeasurement(
      babyId: widget.babyId,
      weightKg: await GrowthBaseline.latestWeightKg(widget.babyId),
      heightCm: await GrowthBaseline.latestHeightCm(widget.babyId),
    );
    unawaited(ProfileCloudSync.pushBaby(widget.babyId));
    GrowthEvents.ping();
    if (mounted) Navigator.pop(context);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final valueField = widget.kind == 'head'
        ? TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            controller: _headCtrl,
            decoration: InputDecoration(
              labelText: '${widget.label} (${widget.unit})',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )
        : _buildPortalGrowthRuler(
            context: context,
            s: s,
            kind: widget.kind,
            label: widget.label,
            baseValue: _rulerBase,
            onBaseChanged: (v) => setState(() => _rulerBase = v),
            onAfterUnitChange: () => setState(() {}),
            subjectLabel: widget.subjectLabel,
            snapStartToZeroWhenAtMax: false,
          );

    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${s.edit} — ${widget.label}',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            valueField,
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(s.viewCalendar),
              subtitle: Text(_fmtDateDdMmYy(_picked)),
              onTap: _pickDate,
            ),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: widget.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _save,
              child: Text(s.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
