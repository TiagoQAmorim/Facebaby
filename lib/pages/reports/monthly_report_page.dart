import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/app_date_picker.dart';
import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../models/baby_memory.dart';
import '../../models/monthly_report_snapshot.dart';
import '../../services/monthly_report_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/measurement_format.dart';
import '../../utils/photo_b64.dart';
import '../../utils/portal_layout.dart';
import '../../utils/portal_page_route.dart';
import '../../widgets/photo_avatar.dart';
import '../memories/memories_page.dart';
import '../memories/memory_badges_catalog.dart';
import 'report_page_shell.dart';

/// Relatório mensal — crescimento, sono, alimentação, marcos e memórias.
class MonthlyReportPage extends StatefulWidget {
  const MonthlyReportPage({super.key, required this.anchorDay});

  /// Qualquer dia dentro do mês de referência.
  final DateTime anchorDay;

  @override
  State<MonthlyReportPage> createState() => _MonthlyReportPageState();
}

class _MonthlyReportPageState extends State<MonthlyReportPage> {
  MonthlyReportSnapshot? _snapshot;
  Object? _error;
  late DateTime _monthAnchor;
  final _babyCtrl = CurrentBabyController.instance;

  static const _purple = Color(0xFF8E7CC3);

  @override
  void initState() {
    super.initState();
    final n = widget.anchorDay;
    _monthAnchor = DateTime(n.year, n.month, 1);
    _babyCtrl.addListener(_onBaby);
    _load();
  }

  @override
  void dispose() {
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
      final snap = await MonthlyReportService.load(
          babyId: id, anchorInMonth: _monthAnchor);
      if (mounted) {
        setState(() {
          _snapshot = snap;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _monthAnchor,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12),
    );
    if (picked != null && mounted) {
      setState(() => _monthAnchor = DateTime(picked.year, picked.month, 1));
      await _load();
    }
  }

  String _monthTitle(BuildContext context) {
    final loc = Localizations.localeOf(context).toString();
    try {
      return DateFormat.yMMMM(loc).format(_monthAnchor);
    } catch (_) {
      return DateFormat.yMMMM().format(_monthAnchor);
    }
  }

  Widget _growthChart(List<MonthlyGrowthPoint> points) {
    if (points.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            S.of(context).reportMonthlyGrowthChartEmpty,
            style: TextStyle(
                color: AppTheme.textMuted, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    final labels = <DateTime>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].value));
      labels.add(points[i].date);
    }

    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final p in spots) {
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    if (minY == maxY) {
      minY -= 0.5;
      maxY += 0.5;
    } else {
      final pad = (maxY - minY) * 0.15;
      minY -= pad;
      maxY += pad;
    }

    final loc = Localizations.localeOf(context).toString();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.black.withAlpha(14), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          minY: minY,
          maxY: maxY,
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(1),
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: math.max(1, (spots.length / 5).floorToDouble()),
                getTitlesWidget: (xVal, _) {
                  final i = xVal.round().clamp(0, labels.length - 1);
                  final d = labels[i];
                  try {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        DateFormat('dd/MM', loc).format(d),
                        style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w700),
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
              curveSmoothness: 0.28,
              barWidth: 3,
              color: _purple,
              dotData: FlDotData(
                show: true,
                getDotPainter: (s, p, bar, i) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: _purple,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _purple.withAlpha(90),
                    _purple.withAlpha(15),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sleepTrendLine(S s, MonthlyReportSnapshot snap) {
    switch (snap.sleepTrendKey) {
      case 'sleep_trend_up':
        return s.reportMonthlySleepTrendUp;
      case 'sleep_trend_down':
        return s.reportMonthlySleepTrendDown;
      case 'sleep_trend_stable':
        return s.reportMonthlySleepTrendStable;
      default:
        return s.reportMonthlySleepTrendUnknown;
    }
  }

  String _formatHour(BuildContext context, int h) {
    final loc = Localizations.localeOf(context).toString();
    try {
      final d = DateTime(2020, 1, 1, h);
      return DateFormat.Hm(loc).format(d);
    } catch (_) {
      return '${h.toString().padLeft(2, '0')}:00';
    }
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
    final babyName =
        (name == null || name.isEmpty) ? s.placeholderBabyName : name;

    final lastDay = DateTime(_monthAnchor.year, _monthAnchor.month + 1, 0);
    final ageLabel = birth == null ? '—' : s.babyAgeLabel(birth, lastDay);

    final reportBg = reportScaffoldBackground();

    return Scaffold(
      backgroundColor: reportBg,
      appBar: AppBar(
        backgroundColor: reportBg,
        surfaceTintColor: reportBg,
        elevation: 0,
        title: Text(s.reportMonthlyScreenTitle,
            style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: bid == null
          ? Center(child: Text(s.feedingNoBabyHint))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    AppTheme.pageHPadding, 0, AppTheme.pageHPadding, 110),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _monthTitle(context),
                          style: TextStyle(
                              fontSize: portalSp(context, 17),
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                          onPressed: _pickMonth,
                          icon: const Icon(Icons.calendar_month_rounded,
                              color: _purple)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      PhotoAvatar(
                        photoB64: babyRow?['photo_b64'] as String?,
                        photoUrl: ((babyRow?['photo_url'] as String?) ?? '')
                                .trim()
                                .isEmpty
                            ? null
                            : (babyRow?['photo_url'] as String?)?.trim(),
                        radius: 26,
                        backgroundColor: AppTheme.softPurple,
                        fallback:
                            const Text('👶', style: TextStyle(fontSize: 28)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(babyName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 19)),
                            Text(ageLabel,
                                style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text('$_error',
                        style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 22),
                  if (snap == null)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(28),
                            child: CircularProgressIndicator()))
                  else ...[
                    Text(s.growth,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _metricCard(
                            title: s.reportMonthlyAvgWeight,
                            value: MeasurementFormat.weight(snap.avgWeightKg,
                                decimalsKg: 3),
                            delta: snap.weightGainGrams != null
                                ? '${snap.weightGainGrams! >= 0 ? '+' : ''}${snap.weightGainGrams}g'
                                : '—',
                            positive: snap.weightGainGrams != null &&
                                snap.weightGainGrams! >= 0,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _metricCard(
                            title: s.reportMonthlyAvgHeight,
                            value: MeasurementFormat.length(snap.avgHeightCm,
                                decimalsCm: 1),
                            delta: snap.heightGainCm != null
                                ? '${snap.heightGainCm! >= 0 ? '+' : ''}${snap.heightGainCm!.toStringAsFixed(1)} cm'
                                : '—',
                            positive: snap.heightGainCm != null &&
                                snap.heightGainCm! >= 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _panel(child: _growthChart(snap.weightPoints)),
                    const SizedBox(height: 26),
                    Text(s.reportMonthlySleepSection,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(
                      s.reportMonthlySleepExplain,
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        height: 1.4,
                        fontSize: portalSp(context, 13),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.reportMonthlySleepAvg,
                              style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w700)),
                          Text(
                            MonthlyHoursFmt.formatHours(
                                snap.avgSleepHoursDaily),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 26),
                          ),
                          if (snap.sleepTrendVsPrevMonthPct != null)
                            Text(
                              '${snap.sleepTrendVsPrevMonthPct! >= 0 ? '+' : ''}${snap.sleepTrendVsPrevMonthPct!.round()}% ${s.reportMonthlyVsPrevMonth}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: snap.sleepTrendVsPrevMonthPct! >= 0
                                    ? const Color(0xFF34C759)
                                    : AppTheme.textMuted,
                              ),
                            ),
                          const SizedBox(height: 10),
                          Text(s.reportMonthlyBestWeeks,
                              style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: snap.bestWeekLabels
                                .map(
                                  (w) => Chip(
                                    label: Text(w,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    backgroundColor:
                                        AppTheme.lavender.withAlpha(180),
                                    side: BorderSide.none,
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 10),
                          Text(_sleepTrendLine(s, snap),
                              style: const TextStyle(
                                  height: 1.35, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(s.reportMonthlyFeedingSection,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(
                      s.reportMonthlyFeedingExplain,
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        height: 1.4,
                        fontSize: portalSp(context, 13),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.reportMonthlyFeedFreq,
                              style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w700)),
                          Text(
                            snap.avgFeedsPerDay.toStringAsFixed(1),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 24),
                          ),
                          const SizedBox(height: 10),
                          Text(s.reportMonthlyPredominantHours,
                              style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          if (snap.topFeedingHours.isEmpty)
                            Text(s.reportNoDataHint,
                                style: TextStyle(color: AppTheme.textMuted))
                          else
                            Wrap(
                              spacing: 8,
                              children: snap.topFeedingHours.map((h) {
                                return Chip(
                                  label: Text(_formatHour(context, h),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  backgroundColor: const Color(0xFFFFF6E8),
                                  side: BorderSide(
                                      color: const Color(0xFFE08A3E)
                                          .withAlpha(80)),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(s.reportMonthlyMilestonesTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 10),
                    _panel(
                      child: snap.milestones.isEmpty
                          ? Text(s.reportMonthlyMilestonesEmpty,
                              style: TextStyle(color: AppTheme.textMuted))
                          : Column(
                              children: snap.milestones.take(12).map((m) {
                                final df = DateFormat.MMMd(
                                    Localizations.localeOf(context).toString());
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.check_circle_rounded,
                                          color: Color(0xFF34C759), size: 22),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _monthlyMilestoneLineTitle(
                                              context, m),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      Text(
                                        df.format(m.date),
                                        style: TextStyle(
                                            color: AppTheme.textMuted,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                            child: Text(s.reportMonthlyMemoriesTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18))),
                        TextButton(
                          onPressed: () {
                            pushPortalPage<void>(context, const MemoriesPage());
                          },
                          child: Text(s.reportMonthlySeeAllMemories,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 88,
                      child: snap.memoriesWithPhoto.isEmpty
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Text(s.reportMonthlyMemoriesEmpty,
                                  style: TextStyle(color: AppTheme.textMuted)),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: snap.memoriesWithPhoto.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (ctx, i) => _MemoryThumb(
                                  memory: snap.memoriesWithPhoto[i]),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.reportMonthlyVideosHint,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String delta,
    required bool positive,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                  positive
                      ? Icons.trending_up_rounded
                      : Icons.trending_flat_rounded,
                  size: 18,
                  color:
                      positive ? const Color(0xFF34C759) : AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(delta,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: positive
                          ? const Color(0xFF34C759)
                          : AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  String _monthlyMilestoneLineTitle(BuildContext context, MonthlyMilestone m) {
    final s = S.of(context);
    switch (m.source) {
      case MonthlyMilestoneSource.consultation:
        return m.title.trim().isEmpty
            ? s.reportMonthlyMilestoneConsultationDefault
            : m.title;
      case MonthlyMilestoneSource.memory:
        final id = m.badgeId?.trim();
        if (id != null && id.isNotEmpty) {
          final badge = MemoryBadgesCatalog.findBadgeById(id);
          if (badge != null) return s.memoryBadgeTitle(badge);
        }
        return m.title;
      case MonthlyMilestoneSource.vaccine:
        return m.title;
    }
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: child,
    );
  }
}

/// Formatação local de horas para o cartão de sono.
class MonthlyHoursFmt {
  static String formatHours(double hours) {
    if (hours <= 0) return '0m';
    final totalMin = (hours * 60).round();
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m';
  }
}

class _MemoryThumb extends StatelessWidget {
  const _MemoryThumb({required this.memory});

  final BabyMemory memory;

  @override
  Widget build(BuildContext context) {
    final b64 = memory.photoB64?.trim();
    final url = memory.photoUrl?.trim();
    final bytes = decodePhotoB64(b64);

    Widget img;
    if (bytes != null) {
      img = Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (url != null && url.isNotEmpty) {
      img = Image.network(url, fit: BoxFit.cover, gaplessPlayback: true);
    } else {
      img = const ColoredBox(
          color: Color(0xFFEDE7F6),
          child: Icon(Icons.image_rounded, color: Color(0xFF8E7CC3)));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(width: 88, height: 88, child: img),
    );
  }
}
