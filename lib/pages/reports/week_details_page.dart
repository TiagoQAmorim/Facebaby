import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../i18n/app_i18n.dart';
import '../../models/daily_summary.dart';
import '../../models/weekly_report_snapshot.dart';
import '../../services/weekly_report_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/portal_layout.dart';

/// Detalhes da semana — sono, mamadas e fraldas num único relatório (sem guias).
class WeekDetailsPage extends StatelessWidget {
  const WeekDetailsPage({super.key, required this.snapshot});

  final WeeklyReportSnapshot snapshot;

  static const _bg = Color(0xFFF5F3FA);

  String _patternLine(S s, String key) {
    switch (key) {
      case 'pattern_weekend_more_sleep':
        return s.reportWeeklyPatternWeekend;
      case 'pattern_feeding_down':
        return s.reportWeeklyPatternFeedingDown;
      default:
        return s.reportWeeklyPatternDefault;
    }
  }

  List<String> _weekdayLabels(BuildContext context, DateTime weekMonday) {
    final loc = Localizations.localeOf(context).toString();
    return List<String>.generate(7, (i) {
      final d = weekMonday.add(Duration(days: i));
      try {
        return DateFormat.E(loc).format(d);
      } catch (_) {
        return DateFormat.E().format(d);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final snap = snapshot;
    final curr = snap.currentWeekDays;
    final prev = snap.previousWeekDays;
    final n = snap.aggregatedDayCount.clamp(0, 7);
    final currSlice = n <= 0 ? <DailySummary>[] : curr.sublist(0, n > curr.length ? curr.length : n);
    final prevSlice = n <= 0 ? <DailySummary>[] : prev.sublist(0, n > prev.length ? prev.length : n);
    final sleepHours = WeeklyReportService.sleepHoursPerDay(curr);
    final avgH = WeeklyReportService.avgSleepHours(currSlice);
    final pctAvg = WeeklyReportService.pctVsPrevWeekAvgSleep(currSlice, prevSlice);
    final labels = _weekdayLabels(context, snap.weekMonday);

    String weekdayLong(DateTime d) {
      final loc = Localizations.localeOf(context).toString();
      try {
        return DateFormat.EEEE(loc).format(d);
      } catch (_) {
        return DateFormat.EEEE().format(d);
      }
    }

    final vs = pctAvg == null ? s.reportWeeklyTrendNA : '${pctAvg >= 0 ? '+' : ''}${pctAvg.round()}%';

    final feedCounts = curr.map<int>((e) => e.feedings).toList();
    final feedDoubles = feedCounts.map((e) => e.toDouble()).toList();
    final diaperCounts = curr.map<int>((e) => e.diapers).toList();
    final diaperDoubles = diaperCounts.map((e) => e.toDouble()).toList();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(s.reportWeekDetailsTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              if (v == 'share') {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.reportShareSoon)));
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'share', child: Text(s.reportShareSoon)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppTheme.pageHPadding, 14, AppTheme.pageHPadding, 110),
        children: [
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.nightlight_round, color: AppTheme.primaryPurple.withAlpha(230)),
                    const SizedBox(width: 8),
                    Text(s.reportTabSleep, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.primaryPurple)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(s.reportWeeklySleepHoursChartTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 12),
                _WeeklyBars(
                  values: sleepHours,
                  maxY: 18,
                  barColor: AppTheme.primaryPurple,
                  labels: labels,
                ),
                const Divider(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.reportWeeklyAvgWeekLabel, style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
                          Text(
                            WeeklyReportService.formatHoursMinutes(avgH),
                            style: TextStyle(fontSize: portalSp(context, 28), fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          vs,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: pctAvg != null && pctAvg >= 0 ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                          ),
                        ),
                        Text(s.reportWeeklyVsPrevWeekShort, style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                if (n > 0 && n < 7) ...[
                  const SizedBox(height: 10),
                  Text(
                    s.reportWeeklyPartialWeekHint(weekdayLong(snap.weekMonday.add(Duration(days: n - 1)))),
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.reportWeeklyPatternsTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 8),
                ...snap.patternKeys.map((k) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.w900)),
                          Expanded(child: Text(_patternLine(s, k), style: const TextStyle(height: 1.35, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(s.reportWeeklyHeatmapSoon, style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.reportWeeklyPatternsTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      const SizedBox(height: 12),
                      ...snap.patternKeys.map((k) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(_patternLine(s, k)),
                          )),
                    ],
                  ),
                ),
              );
            },
            child: Text(s.reportWeeklySeeAllAnalyses, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 18),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.restaurant_outlined, color: const Color(0xFFE08A3E).withAlpha(230)),
                    const SizedBox(width: 8),
                    Text(s.reportTabFeedings, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFFE08A3E))),
                  ],
                ),
                const SizedBox(height: 12),
                Text(s.reportWeeklyFeedChartCaption, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 12),
                _WeeklyBars(
                  values: feedDoubles,
                  maxY: math.max(12.0, feedDoubles.fold<double>(0, math.max)),
                  barColor: const Color(0xFFE08A3E),
                  labels: labels,
                ),
                const SizedBox(height: 12),
                Text(
                  s.reportWeeklyAvgFeedsDay(snap.avgDailyFeedings.toStringAsFixed(1)),
                  style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.baby_changing_station_rounded, color: AppTheme.babyBlue.withAlpha(230)),
                    const SizedBox(width: 8),
                    Text(s.reportTabDiapers, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.babyBlue)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(s.reportWeeklyDiaperChartCaption, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 12),
                _WeeklyBars(
                  values: diaperDoubles,
                  maxY: math.max(14.0, diaperDoubles.fold<double>(0, math.max)),
                  barColor: AppTheme.babyBlue,
                  labels: labels,
                ),
                const SizedBox(height: 12),
                Text(
                  s.reportWeeklyAvgDiapersDay(snap.avgDailyDiapers.toStringAsFixed(1)),
                  style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({
    required this.values,
    required this.maxY,
    required this.barColor,
    required this.labels,
  });

  final List<double> values;
  final double maxY;
  final Color barColor;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (values.length != 7 || labels.length != 7) return const SizedBox.shrink();
    final cap = math.max(1.0, maxY);
    const chartHeight = 160.0;

    return Column(
      children: [
        SizedBox(
          height: chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final v = values[i].clamp(0.0, cap);
              final t = v / cap;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: t.clamp(0.04, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [barColor.withAlpha(230), barColor.withAlpha(110)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(7, (i) {
            return Expanded(
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.textMuted),
              ),
            );
          }),
        ),
      ],
    );
  }
}
