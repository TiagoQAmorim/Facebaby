import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../models/advanced_sleep_report_snapshot.dart';
import '../../services/advanced_sleep_report_service.dart';
import '../../services/weekly_report_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/portal_layout.dart';
import '../../widgets/photo_avatar.dart';

/// Relatório avançado de sono — score, métricas derivadas de registos e gráficos suaves.
class AdvancedSleepReportPage extends StatefulWidget {
  const AdvancedSleepReportPage({super.key, required this.anchorDay});

  final DateTime anchorDay;

  @override
  State<AdvancedSleepReportPage> createState() => _AdvancedSleepReportPageState();
}

class _AdvancedSleepReportPageState extends State<AdvancedSleepReportPage> with SingleTickerProviderStateMixin {
  AdvancedSleepReportSnapshot? _snapshot;
  Object? _error;
  late DateTime _anchor;
  final _babyCtrl = CurrentBabyController.instance;
  late AnimationController _gaugeCtrl;
  late Animation<double> _gaugeAnim;

  static const _bg = Color(0xFFF4F2FB);
  static const _purple = Color(0xFF8E7CC3);
  static const _green = Color(0xFF34C759);
  static const _sky = Color(0xFF74B9FF);

  @override
  void initState() {
    super.initState();
    final n = widget.anchorDay;
    _anchor = DateTime(n.year, n.month, n.day);
    _gaugeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _gaugeAnim = CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic);
    _babyCtrl.addListener(_onBaby);
    _load();
  }

  @override
  void dispose() {
    _gaugeCtrl.dispose();
    _babyCtrl.removeListener(_onBaby);
    super.dispose();
  }

  void _onBaby() => _load();

  Future<void> _load() async {
    final id = _babyCtrl.currentBabyId;
    if (id == null) {
      if (mounted) setState(() => _snapshot = null);
      return;
    }
    try {
      final snap = await AdvancedSleepReportService.load(babyId: id, anchorDay: _anchor);
      if (mounted) {
        setState(() {
          _snapshot = snap;
          _error = null;
        });
        _gaugeCtrl.forward(from: 0);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pickWeekDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null && mounted) {
      setState(() => _anchor = DateTime(picked.year, picked.month, picked.day));
      await _load();
    }
  }

  String _weekRangeLabel(BuildContext context, DateTime monday) {
    final end = monday.add(const Duration(days: 6));
    final loc = Localizations.localeOf(context).toString();
    try {
      if (monday.year == end.year && monday.month == end.month) {
        return '${monday.day} – ${DateFormat('d MMMM y', loc).format(end)}';
      }
      return '${DateFormat.yMMMd(loc).format(monday)} – ${DateFormat.yMMMd(loc).format(end)}';
    } catch (_) {
      return '${monday.day}/${monday.month} – ${end.day}/${end.month}/${end.year}';
    }
  }

  String _statusLabel(S s, String key) {
    switch (key) {
      case 'excellent':
        return s.reportSleepAdvStatusExcellent;
      case 'good':
        return s.reportSleepAdvStatusGood;
      case 'regular':
        return s.reportSleepAdvStatusRegular;
      default:
        return s.reportSleepAdvStatusPoor;
    }
  }

  String _efficiencyBadge(S s, double pct) {
    if (pct >= 88) return s.reportSleepAdvBadgeVeryGood;
    if (pct >= 78) return s.reportSleepAdvBadgeGood;
    if (pct >= 65) return s.reportSleepAdvBadgeOk;
    return s.reportSleepAdvBadgeAttention;
  }

  String _onsetBadge(S s, double minutes) {
    if (minutes <= 0) return s.reportSleepAdvBadgeUnknown;
    if (minutes <= 25) return s.reportSleepAdvBadgeIdeal;
    if (minutes <= 45) return s.reportSleepAdvBadgeGood;
    return s.reportSleepAdvBadgeOk;
  }

  String _awakenBadge(S s, double avg) {
    if (avg <= 1.2) return s.reportSleepAdvBadgeLow;
    if (avg <= 2.8) return s.reportSleepAdvBadgeModerate;
    return s.reportSleepAdvBadgeHigh;
  }

  String _longestBadge(S s, int sec) {
    final h = sec / 3600.0;
    if (h >= 5) return s.reportSleepAdvBadgeVeryGood;
    if (h >= 3.5) return s.reportSleepAdvBadgeGood;
    if (h >= 2) return s.reportSleepAdvBadgeOk;
    return s.reportSleepAdvBadgeAttention;
  }

  String _avgSleepBadge(S s, double hours) {
    if (hours >= 11) return s.reportSleepAdvBadgeVeryGood;
    if (hours >= 9) return s.reportSleepAdvBadgeGood;
    if (hours >= 6.5) return s.reportSleepAdvBadgeOk;
    return s.reportSleepAdvBadgeAttention;
  }

  String _formatIdealWindow(BuildContext context, AdvancedSleepReportSnapshot snap) {
    final h = snap.idealBedtimeHour;
    final m = snap.idealBedtimeMinute;
    if (h == null || m == null) return '—';
    final loc = Localizations.localeOf(context).toString();
    final center = DateTime(2020, 1, 1, h, m);
    final start = center.subtract(const Duration(minutes: 15));
    final end = center.add(const Duration(minutes: 15));
    try {
      return '${DateFormat.Hm(loc).format(start)} – ${DateFormat.Hm(loc).format(end)}';
    } catch (_) {
      return '${start.hour}:${start.minute.toString().padLeft(2, '0')} – ${end.hour}:${end.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatMinutes(double m) {
    if (m <= 0) return '—';
    return '${m.round()} min';
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }

  Widget _metricRow({
    required String label,
    required String value,
    required String badge,
    required Color badgeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary, fontSize: portalSp(context, 14))),
          ),
          Expanded(
            flex: 4,
            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(width: 4, height: 18, decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    badge,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: badgeColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineChart(AdvancedSleepReportSnapshot snap) {
    final spots = <FlSpot>[];
    for (var i = 0; i < snap.lineSeriesSleepHours.length; i++) {
      spots.add(FlSpot(i.toDouble(), snap.lineSeriesSleepHours[i]));
    }
    if (spots.isEmpty) return const SizedBox.shrink();

    var minY = 0.0;
    var maxY = 18.0;
    for (final p in spots) {
      maxY = math.max(maxY, p.y + 1);
    }

    final loc = Localizations.localeOf(context).toString();
    final labels = List<DateTime>.generate(7, (i) => snap.weekMonday.add(Duration(days: i)));

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          clipData: const FlClipData.all(),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.black.withAlpha(12))),
          borderData: FlBorderData(show: false),
          minY: minY,
          maxY: maxY,
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text(
                  '${v.round()}h',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (xVal, _) {
                  final i = xVal.round().clamp(0, 6);
                  try {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        DateFormat.E(loc).format(labels[i]),
                        style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                      ),
                    );
                  } catch (_) {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              barWidth: 3.5,
              color: _purple,
              dotData: FlDotData(
                show: true,
                getDotPainter: (s0, p, b, i) => FlDotCirclePainter(radius: 4.5, color: Colors.white, strokeWidth: 2.5, strokeColor: _purple),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_purple.withAlpha(100), _purple.withAlpha(14)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compareLines(AdvancedSleepReportSnapshot snap) {
    final curr = <FlSpot>[];
    final prev = <FlSpot>[];
    for (var i = 0; i < 7; i++) {
      curr.add(FlSpot(i.toDouble(), snap.lineSeriesSleepHours[i]));
      prev.add(FlSpot(i.toDouble(), snap.prevWeekSleepHours[i]));
    }
    var maxY = 18.0;
    for (final p in [...curr, ...prev]) {
      maxY = math.max(maxY, p.y + 1);
    }
    final loc = Localizations.localeOf(context).toString();
    final labels = List<DateTime>.generate(7, (i) => snap.weekMonday.add(Duration(days: i)));

    return SizedBox(
      height: 210,
      child: LineChart(
        LineChartData(
          clipData: const FlClipData.all(),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.black.withAlpha(10))),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: maxY,
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (v, _) => Text('${v.round()}h', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (xVal, _) {
                  final i = xVal.round().clamp(0, 6);
                  try {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(DateFormat.E(loc).format(labels[i]), style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                    );
                  } catch (_) {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: curr,
              isCurved: true,
              curveSmoothness: 0.3,
              barWidth: 3,
              color: _purple,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: prev,
              isCurved: true,
              curveSmoothness: 0.3,
              barWidth: 2.5,
              color: _sky.withAlpha(180),
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _donut(S s, AdvancedSleepReportSnapshot snap) {
    final dayH = snap.daySleepHoursWeek;
    final nightH = snap.nightSleepHoursWeek;
    final total = dayH + nightH;
    if (total <= 0.01) {
      return Text(s.reportSleepAdvDistributionEmpty, style: TextStyle(color: AppTheme.textMuted));
    }
    final dayPct = dayH / total * 100;
    final nightPct = nightH / total * 100;

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sectionsSpace: 3,
          centerSpaceRadius: 52,
          sections: [
            PieChartSectionData(
              color: _sky.withAlpha(230),
              value: math.max(0.01, dayH),
              title: '${dayPct.round()}%',
              radius: 44,
              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            PieChartSectionData(
              color: _purple.withAlpha(230),
              value: math.max(0.01, nightH),
              title: '${nightPct.round()}%',
              radius: 44,
              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundedBars(S s, AdvancedSleepReportSnapshot snap) {
    const h = 168.0;
    final allHours = [...snap.lineSeriesSleepHours, ...snap.prevWeekSleepHours];
    final cap = allHours.isEmpty ? 18.0 : math.max(18.0, allHours.reduce(math.max) + 1.0);
    return SizedBox(
      height: h + 28,
      child: Column(
        children: [
          SizedBox(
            height: h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final a = snap.lineSeriesSleepHours[i].clamp(0.0, cap) / cap;
                final b = snap.prevWeekSleepHours[i].clamp(0.0, cap) / cap;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: math.max(0.06, a),
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [_purple.withAlpha(230), _purple.withAlpha(120)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: math.max(0.06, b),
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [_sky.withAlpha(200), _sky.withAlpha(90)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(_purple, s.reportSleepAdvLegendThisWeek),
              const SizedBox(width: 16),
              _legendDot(_sky, s.reportSleepAdvLegendPrevWeek),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bid = _babyCtrl.currentBabyId;
    final babyRow = _babyCtrl.currentBabyRow;
    final snap = _snapshot;

    final birthRaw = babyRow?['birth_date'] as String?;
    final birth = DateTime.tryParse(birthRaw ?? '');
    final name = (babyRow?['name'] as String?)?.trim();
    final babyName = (name == null || name.isEmpty) ? s.placeholderBabyName : name;

    final weekEnd = snap == null ? _anchor : snap.weekMonday.add(const Duration(days: 6));
    final ageLabel = birth == null ? '—' : s.babyAgeLabel(birth, weekEnd);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(s.reportSleepAdvScreenTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: _pickWeekDay, icon: const Icon(Icons.calendar_month_rounded, color: _purple)),
        ],
      ),
      body: bid == null
          ? Center(child: Text(s.feedingNoBabyHint))
          : _error != null
              ? Center(child: SelectableText('$_error'))
              : snap == null
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(AppTheme.pageHPadding, 0, AppTheme.pageHPadding, 120),
                        children: [
                          Text(
                            _weekRangeLabel(context, snap.weekMonday),
                            style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w700, fontSize: portalSp(context, 14)),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              PhotoAvatar(
                                photoB64: babyRow?['photo_b64'] as String?,
                                photoUrl: ((babyRow?['photo_url'] as String?) ?? '').trim().isEmpty
                                    ? null
                                    : (babyRow?['photo_url'] as String?)?.trim(),
                                radius: 28,
                                backgroundColor: AppTheme.softPurple,
                                fallback: const Text('👶', style: TextStyle(fontSize: 28)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(babyName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                                    Text(ageLabel, style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          if (!snap.hasEnoughData)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(s.reportSleepAdvNotEnoughData, style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                            ),
                          _SleepScoreHero(
                            animation: _gaugeAnim,
                            score: snap.sleepScore,
                            statusLabel: _statusLabel(s, snap.statusKey),
                            purple: _purple,
                            green: _green,
                          ),
                          const SizedBox(height: 14),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.reportSleepAdvMetricsTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                                const Divider(height: 22),
                                _metricRow(
                                  label: s.reportSleepAdvEfficiency,
                                  value: '${snap.sleepEfficiencyPct.round()}%',
                                  badge: _efficiencyBadge(s, snap.sleepEfficiencyPct),
                                  badgeColor: _green,
                                ),
                                if (AdvancedSleepReportService.efficiencyPctVsPrev(snap) != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                                    child: Text(
                                      s.reportSleepAdvVsPrevPct(AdvancedSleepReportService.efficiencyPctVsPrev(snap)!.round()),
                                      style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                const Divider(height: 1),
                                _metricRow(
                                  label: s.reportSleepAdvOnset,
                                  value: _formatMinutes(snap.sleepOnsetMinutesAvg),
                                  badge: _onsetBadge(s, snap.sleepOnsetMinutesAvg),
                                  badgeColor: _green,
                                ),
                                const Divider(height: 1),
                                _metricRow(
                                  label: s.reportSleepAdvAwakenings,
                                  value: snap.awakeningsAvgNightly <= 0 ? '—' : snap.awakeningsAvgNightly.toStringAsFixed(1),
                                  badge: snap.awakeningsAvgNightly <= 0 ? s.reportSleepAdvBadgeUnknown : _awakenBadge(s, snap.awakeningsAvgNightly),
                                  badgeColor: _green,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                                  child: Text(
                                    s.reportSleepAdvAwakeningsTotal(snap.awakeningsTotalWeek),
                                    style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const Divider(height: 1),
                                _metricRow(
                                  label: s.reportSleepAdvLongest,
                                  value: WeeklyReportService.formatHoursMinutes(snap.longestContinuousSleepSec / 3600.0),
                                  badge: _longestBadge(s, snap.longestContinuousSleepSec),
                                  badgeColor: _green,
                                ),
                                const Divider(height: 1),
                                _metricRow(
                                  label: s.reportSleepAdvAvgDailySleep,
                                  value: WeeklyReportService.formatHoursMinutes(
                                    snap.currentWeekDays.fold<int>(0, (a, d) => a + d.sleepTotalSeconds) / math.max(1, snap.currentWeekDays.length) / 3600.0,
                                  ),
                                  badge: _avgSleepBadge(
                                    s,
                                    snap.currentWeekDays.fold<int>(0, (a, d) => a + d.sleepTotalSeconds) / math.max(1, snap.currentWeekDays.length) / 3600.0,
                                  ),
                                  badgeColor: _green,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.reportSleepAdvIdealTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                                const SizedBox(height: 12),
                                Text(
                                  _formatIdealWindow(context, snap),
                                  style: TextStyle(fontSize: portalSp(context, 28), fontWeight: FontWeight.w900, color: _purple),
                                ),
                                const SizedBox(height: 8),
                                Text(s.reportSleepAdvIdealFooter, style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(s.reportSleepAdvChartsSection, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                          const SizedBox(height: 12),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.reportSleepAdvChartsSleepTrend, style: const TextStyle(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 8),
                                _lineChart(snap),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.reportSleepAdvChartsCompare, style: const TextStyle(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 6),
                                _compareLines(snap),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.reportSleepAdvChartsDistribution, style: const TextStyle(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: _donut(s, snap)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s.reportSleepAdvDayPhase, style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
                                          Text(
                                            WeeklyReportService.formatHoursMinutes(snap.daySleepHoursWeek),
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(s.reportSleepAdvNightPhase, style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
                                          Text(
                                            WeeklyReportService.formatHoursMinutes(snap.nightSleepHoursWeek),
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.reportSleepAdvChartsBars, style: const TextStyle(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 10),
                                _roundedBars(s, snap),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.reportSleepAdvScoreBreakdown, style: const TextStyle(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 8),
                                Text(
                                  s.reportSleepAdvBreakdownLine(
                                    snap.scoreEfficiencyPoints.round(),
                                    snap.scoreStretchPoints.round(),
                                    snap.scoreAwakenPoints.round(),
                                    snap.scoreConsistencyPoints.round(),
                                  ),
                                  style: const TextStyle(height: 1.4, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
    );
  }
}

class _SleepScoreHero extends StatelessWidget {
  const _SleepScoreHero({
    required this.animation,
    required this.score,
    required this.statusLabel,
    required this.purple,
    required this.green,
  });

  final Animation<double> animation;
  final int score;
  final String statusLabel;
  final Color purple;
  final Color green;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: LayoutBuilder(
      builder: (context, cons) {
        final w = cons.maxWidth;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.reportSleepAdvScoreTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: animation,
                    builder: (ctx, _) {
                      final v = (score * animation.value).round();
                      return Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '$v', style: TextStyle(fontSize: portalSp(context, 36), fontWeight: FontWeight.w900, height: 1.05)),
                            TextSpan(text: '/100', style: TextStyle(fontSize: portalSp(context, 20), fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(statusLabel, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: green)),
                ],
              ),
            ),
            SizedBox(
              width: math.min(200, w * 0.42),
              height: 130,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: animation,
                      builder: (ctx, _) {
                        return CustomPaint(
                          painter: _SleepGaugePainter(
                            progress: (score / 100.0) * animation.value,
                            purple: purple,
                            green: green,
                          ),
                        );
                      },
                    ),
                  ),
                  const Positioned(
                    bottom: 6,
                    left: 0,
                    right: 0,
                    child: _MoonCloudsRow(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
    );
  }
}

class _SleepGaugePainter extends CustomPainter {
  _SleepGaugePainter({required this.progress, required this.purple, required this.green});

  final double progress;
  final Color purple;
  final Color green;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.92;
    final r = math.min(size.width, size.height * 1.15) / 2;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = purple.withAlpha(36);

    final fgPaint = Paint()
      ..shader = LinearGradient(
        colors: [green, const Color(0xFF5ECFB8), purple],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawArc(rect, math.pi, math.pi, false, bgPaint);

    final sweep = math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(rect, math.pi, sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _SleepGaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _MoonCloudsRow extends StatelessWidget {
  const _MoonCloudsRow();

  static const _kBabySleepAsset = 'assets/sleep/baby_sleep.png';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        _kBabySleepAsset,
        height: 54,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => Icon(Icons.nightlight_round, size: 40, color: Colors.white.withAlpha(220)),
      ),
    );
  }
}
