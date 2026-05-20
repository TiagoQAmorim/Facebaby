import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../models/daily_report_snapshot.dart';
import '../../services/daily_report_service.dart'
    show DailyReportService, formatTimeHm;
import '../../theme/app_theme.dart';
import '../../utils/portal_layout.dart';
import 'report_page_shell.dart';

/// Detalhes do dia — sono, mamadas, fraldas e timeline num único relatório (sem separadores por guias).
class DayDetailsPage extends StatelessWidget {
  const DayDetailsPage({
    super.key,
    required this.calendarDay,
    required this.snapshot,
  });

  final DateTime calendarDay;
  final DailyReportSnapshot snapshot;

  String _benchmarkTitle(S s, String band) {
    switch (band) {
      case 'above':
        return s.reportBenchmarkAbove;
      case 'below':
        return s.reportBenchmarkBelow;
      default:
        return s.reportBenchmarkNear;
    }
  }

  Color _benchmarkColor(String band) {
    switch (band) {
      case 'above':
        return const Color(0xFF34C759);
      case 'below':
        return const Color(0xFFFF9500);
      default:
        return AppTheme.primaryPurple;
    }
  }

  List<String> _insights(S s, DailyReportSnapshot snap) {
    final out = <String>[];
    void addOnce(String x) {
      if (!out.contains(x)) out.add(x);
    }

    if (snap.ageSleepBenchmarkBand == 'above' ||
        snap.ageSleepBenchmarkBand == 'near') {
      addOnce(s.reportInsightSleepAgeGood);
    } else if (snap.ageSleepBenchmarkBand == 'below') {
      addOnce(s.reportInsightSleepAgeLow);
    }
    if (snap.summary.feedings >= 8) addOnce(s.reportInsightFeedsOften);
    if (snap.summary.diapers >= 10) addOnce(s.reportInsightDiapersFrequent);
    if (out.isEmpty) addOnce(s.reportInsightSleepAgeGood);
    if (out.length > 5) return out.sublist(0, 5);
    return out;
  }

  String _diaperKindLabel(S s, String? raw) {
    final k = raw?.toLowerCase().trim() ?? '';
    if (k == 'pee') return s.diaperKindPee;
    if (k == 'poo') return s.diaperKindPoo;
    if (k == 'both') return s.diaperKindBoth;
    return k.isEmpty ? '—' : k;
  }

  String _sleepQualityFromCounts(S s, Map<String, int> c) {
    var best = 'good';
    var n = -1;
    for (final e in c.entries) {
      if (e.value > n) {
        n = e.value;
        best = e.key;
      }
    }
    if (n <= 0) return s.reportSleepQualityMixed;
    switch (best) {
      case 'good':
        return s.reportSleepQualityGood;
      case 'ok':
        return s.reportSleepQualityOk;
      case 'bad':
        return s.reportSleepQualityBad;
      default:
        return s.reportSleepQualityMixed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final snap = snapshot;

    final vs = snap.sleepVsYesterdayPercent;
    final vsStr = vs == null
        ? s.reportVsYesterdayNA
        : '${vs >= 0 ? '+' : ''}${vs.round()}%';
    final longestHint =
        snap.longestSleepStart != null && snap.longestSleepEnd != null
            ? s.reportLongestStretchHint
                .replaceAll('{start}', formatTimeHm(snap.longestSleepStart))
                .replaceAll('{end}', formatTimeHm(snap.longestSleepEnd))
            : '—';

    final reportBg = reportScaffoldBackground();

    return Scaffold(
      backgroundColor: reportBg,
      appBar: AppBar(
        backgroundColor: reportBg,
        surfaceTintColor: reportBg,
        elevation: 0,
        title: Text(s.reportDayDetailsTitle,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              if (v == 'share') {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(s.reportShareSoon)));
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'share', child: Text(s.reportShareSoon)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            AppTheme.pageHPadding, 14, AppTheme.pageHPadding, 110),
        children: [
          _pastelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.nightlight_round,
                        color: AppTheme.primaryPurple.withAlpha(230)),
                    const SizedBox(width: 8),
                    Text(s.reportTabSleep,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: AppTheme.primaryPurple)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snap.summary.sleep,
                            style: TextStyle(
                                fontSize: portalSp(context, 32),
                                fontWeight: FontWeight.w900,
                                height: 1.05),
                          ),
                          Text(s.reportDailySubtitleTotalSleep,
                              style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          vsStr,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: vs != null && vs >= 0
                                ? const Color(0xFF34C759)
                                : const Color(0xFFFF3B30),
                          ),
                        ),
                        Text(s.reportVsYesterdayShort,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(s.reportSleepChartCaption,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMuted,
                        fontSize: 12)),
                const SizedBox(height: 8),
                _HourBars(
                    values: snap.sleepSecondsPerHour,
                    barColor: AppTheme.primaryPurple),
                const Divider(height: 28),
                _kvRow(
                    s.reportDailySubtitleLongestStretch,
                    DailyReportService.formatDurationShort(
                        snap.longestSleepSessionSec),
                    sub: longestHint),
                const Divider(height: 22),
                _kvRow(s.reportNapsLabel, '${snap.napCount}',
                    sub: s.reportTotalSmallLabel),
                const Divider(height: 22),
                _kvRow(s.reportDailySubtitleSleepQuality,
                    _sleepQualityFromCounts(s, snap.sleepQualityCounts)),
                const SizedBox(height: 18),
                Text(s.reportComparedAgeLabel,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _benchmarkTitle(s, snap.ageSleepBenchmarkBand),
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _benchmarkColor(snap.ageSleepBenchmarkBand)),
                      ),
                    ),
                    Text('${snap.ageSleepBenchmarkPercent}%',
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: snap.ageSleepBenchmarkPercent / 100.0,
                    minHeight: 10,
                    backgroundColor: AppTheme.softPurple,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _pastelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.reportTabFeedings,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Color(0xFFE08A3E))),
                const SizedBox(height: 12),
                _kvRow(
                    s.reportDailySubtitleFeedTotal, '${snap.summary.feedings}',
                    sub: s.reportTotalSmallLabel),
                const Divider(height: 20),
                _kvRow(
                  s.reportDailySubtitleFeedAvg,
                  snap.avgFeedingDurationSec > 0
                      ? DailyReportService.formatDurationShort(
                          snap.avgFeedingDurationSec)
                      : '—',
                ),
                const Divider(height: 20),
                _kvRow(s.reportDailySubtitleFeedLast,
                    formatTimeHm(snap.lastFeedingEndedAt)),
                const SizedBox(height: 18),
                Text(s.reportFeedingChartCaption,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMuted,
                        fontSize: 12)),
                const SizedBox(height: 8),
                _HourBars(
                    values: snap.feedingCountPerHour,
                    barColor: const Color(0xFFE08A3E)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _pastelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.reportTabDiapers,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: AppTheme.babyBlue)),
                const SizedBox(height: 12),
                _kvRow(s.reportDailySubtitleDiaperTotal,
                    '${snap.summary.diapers}'),
                const Divider(height: 20),
                _kvRow(s.reportDailySubtitleDiaperWet,
                    '${snap.summary.diaperPee}'),
                const Divider(height: 20),
                _kvRow(s.reportDailySubtitleDiaperDirty,
                    '${snap.summary.diaperPoo}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _pastelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.reportAiInsightsTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 8),
                ..._insights(s, snap).map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✨ ', style: TextStyle(fontSize: 14)),
                        Expanded(
                            child: Text(t,
                                style: const TextStyle(
                                    height: 1.35,
                                    fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(s.reportTimelineTitle,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ...snap.timeline
                    .map((e) => _timelineTile(context, s, e, _diaperKindLabel)),
                if (snap.timeline.isEmpty)
                  Text(s.reportNoDataHint,
                      style: TextStyle(color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pastelCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _kvRow(String k, String v, {String? sub}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child: Text(k,
                style: TextStyle(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5))),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(v,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            if (sub != null)
              Text(sub,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

Widget _timelineTile(
  BuildContext context,
  S s,
  DailyTimelineEntry e,
  String Function(S, String?) diaperKindLabel,
) {
  final icon = switch (e.kind) {
    DailyTimelineKind.sleep => Icons.nightlight_round,
    DailyTimelineKind.feeding => Icons.restaurant_rounded,
    DailyTimelineKind.diaper => Icons.baby_changing_station_rounded,
  };
  final color = switch (e.kind) {
    DailyTimelineKind.sleep => AppTheme.primaryPurple,
    DailyTimelineKind.feeding => const Color(0xFFE08A3E),
    DailyTimelineKind.diaper => AppTheme.babyBlue,
  };
  final title = switch (e.kind) {
    DailyTimelineKind.sleep => s.shortcutSleep,
    DailyTimelineKind.feeding => s.reportTabFeedings,
    DailyTimelineKind.diaper => s.shortcutDiaper,
  };
  final detail = e.kind == DailyTimelineKind.diaper
      ? diaperKindLabel(s, e.detail)
      : (e.detail ?? '');

  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatTimeHm(e.at)} · $title',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              if (detail.isNotEmpty)
                Text(detail,
                    style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HourBars extends StatelessWidget {
  const _HourBars({required this.values, required this.barColor});

  final List<int> values;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    if (values.length != 24) return const SizedBox.shrink();
    final maxV = math.max(1, values.reduce(math.max));
    const height = 132.0;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(24, (h) {
              final v = values[h];
              final t = v / maxV;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: t.clamp(0.05, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              barColor.withAlpha(210),
                              barColor.withAlpha(120),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(24, (h) {
            final label = h % 3 == 0 ? h.toString().padLeft(2, '0') : '';
            return Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 9,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700),
              ),
            );
          }),
        ),
      ],
    );
  }
}
