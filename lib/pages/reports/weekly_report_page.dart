import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../models/daily_summary.dart';
import '../../models/weekly_report_snapshot.dart';
import '../../services/weekly_report_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/portal_layout.dart';
import '../../utils/portal_page_route.dart';
import '../../widgets/photo_avatar.dart';
import 'report_page_shell.dart';
import 'week_details_page.dart';

/// Relatório semanal — resumo + tendências; detalhes em [WeekDetailsPage].
class WeeklyReportPage extends StatefulWidget {
  const WeeklyReportPage({super.key, required this.anchorDay});

  /// Qualquer dia da semana de referência (usa a semana ISO que o contém).
  final DateTime anchorDay;

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  WeeklyReportSnapshot? _snapshot;
  Object? _error;
  late DateTime _anchor;
  final _babyCtrl = CurrentBabyController.instance;

  static const _heroPurple = Color(0xFF8E7CC3);

  @override
  void initState() {
    super.initState();
    final n = widget.anchorDay;
    _anchor = DateTime(n.year, n.month, n.day);
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
      if (mounted) {
        setState(() {
          _snapshot = null;
          _error = null;
        });
      }
      return;
    }
    if (mounted) setState(() => _error = null);
    try {
      final snap =
          await WeeklyReportService.load(babyId: id, anchorDay: _anchor);
      if (mounted) {
        setState(() {
          _snapshot = snap;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _snapshot = null;
        });
      }
    }
  }

  Future<void> _pickDayInWeek() async {
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

  String _weekdayName(BuildContext context, DateTime day) {
    final loc = Localizations.localeOf(context).toString();
    try {
      return DateFormat.EEEE(loc).format(day);
    } catch (_) {
      return DateFormat.EEEE().format(day);
    }
  }

  String _heroParagraph(S s, WeeklyReportSnapshot w, String babyName) {
    final tone = w.narrativeToneKey == 'calm'
        ? s.reportWeeklyToneCalm
        : s.reportWeeklyToneActive;
    final sp = w.sleepPctVsPrev;
    final hasCurrentData = w.aggregatedDayCount > 0 &&
        (w.avgDailyFeedings > 0 ||
            w.avgDailyDiapers > 0 ||
            w.currentWeekDays
                .take(w.aggregatedDayCount)
                .any((d) => d.sleepTotalSeconds > 0));
    // Em vez de “Sem dados suficientes para comparar…”, quando estamos na primeira
    // semana com dados (sem histórico anterior) descrevemos o que JÁ foi registado.
    final sleepSentence = sp == null
        ? (hasCurrentData
            ? s.reportWeeklyFirstWeekSleepLine
            : s.reportWeeklySleepUnknown)
        : sp.abs() < 4
            ? s.reportWeeklySleepStableShort
            : sp > 0
                ? s.reportWeeklySleepUp(sp.round())
                : s.reportWeeklySleepDown(sp.round().abs());
    final fp = w.feedingPctVsPrev;
    final feedSentence = fp == null || fp.abs() < 6
        ? s.reportWeeklyFeedStableLine
        : fp < 0
            ? s.reportWeeklyFeedDown(fp.round().abs())
            : s.reportWeeklyFeedUp(fp.round());
    return s.reportWeeklyHeroTemplate(
        babyName, tone, sleepSentence, feedSentence);
  }

  String _highlightLine(S s, WeeklyReportSnapshot w) {
    switch (w.highlightKey) {
      case 'highlight_sleep':
        return s.reportWeeklyHighlightSleep;
      case 'highlight_feeding_stable':
        return s.reportWeeklyHighlightFeedingStable;
      case 'highlight_diaper_up':
        return s.reportWeeklyHighlightDiaperUp;
      case 'highlight_weight':
        return s.reportWeeklyHighlightWeight;
      default:
        return s.reportWeeklyHighlightGeneric;
    }
  }

  String _trendLabel(S s, WeeklyTrendBand band, {required bool forWeight}) {
    if (forWeight) {
      switch (band) {
        case WeeklyTrendBand.improved:
          return s.reportWeeklyTrendLabelEvolving;
        case WeeklyTrendBand.worse:
          return s.reportWeeklyTrendLabelWorse;
        case WeeklyTrendBand.stable:
          return s.reportWeeklyTrendLabelStable;
        case WeeklyTrendBand.unknown:
          return s.reportWeeklyTrendLabelUnknown;
      }
    }
    switch (band) {
      case WeeklyTrendBand.improved:
        return s.reportWeeklyTrendLabelImproved;
      case WeeklyTrendBand.worse:
        return s.reportWeeklyTrendLabelWorse;
      case WeeklyTrendBand.stable:
        return s.reportWeeklyTrendLabelStable;
      case WeeklyTrendBand.unknown:
        return s.reportWeeklyTrendLabelUnknown;
    }
  }

  /// Badge "% vs semana anterior" — só devolve algo quando a comparação é conhecida.
  /// Quando volta `null`, o cartão mostra apenas o valor absoluto atual (evita o
  /// efeito “tudo vazio” em semanas onde ainda não há histórico para comparar).
  String? _comparisonBadge(WeeklyTrendBand band, double? pct) {
    if (pct == null || band == WeeklyTrendBand.unknown) return null;
    if (band == WeeklyTrendBand.stable) return '≈ 0%';
    final p = pct.round();
    return '${p > 0 ? '+' : ''}$p%';
  }

  Color _trendColor(WeeklyTrendBand band) {
    switch (band) {
      case WeeklyTrendBand.improved:
        return const Color(0xFF34C759);
      case WeeklyTrendBand.worse:
        return const Color(0xFFFF9500);
      case WeeklyTrendBand.stable:
        return AppTheme.textMuted;
      case WeeklyTrendBand.unknown:
        return AppTheme.textMuted;
    }
  }

  IconData _trendIcon(WeeklyTrendBand band) {
    switch (band) {
      case WeeklyTrendBand.improved:
        return Icons.trending_up_rounded;
      case WeeklyTrendBand.worse:
        return Icons.trending_down_rounded;
      case WeeklyTrendBand.stable:
        return Icons.horizontal_rule_rounded;
      case WeeklyTrendBand.unknown:
        return Icons.help_outline_rounded;
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
    final ageAtEndOfWeek = birth == null
        ? '—'
        : s.babyAgeLabel(birth,
            snap?.weekMonday.add(const Duration(days: 6)) ?? DateTime.now());
    final photoB64 = babyRow?['photo_b64'] as String?;
    final photoUrl = (babyRow?['photo_url'] as String?)?.trim();

    final reportBg = reportScaffoldBackground();

    return Scaffold(
      backgroundColor: reportBg,
      appBar: AppBar(
        backgroundColor: reportBg,
        surfaceTintColor: reportBg,
        elevation: 0,
        title: Text(s.reportWeeklyScreenTitle,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: s.reportWeeklyPickWeekTooltip,
            onPressed: _pickDayInWeek,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      body: bid == null
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(s.feedingNoBabyHint)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    AppTheme.pageHPadding, 0, AppTheme.pageHPadding, 110),
                children: [
                  if (snap != null) ...[
                    Text(
                      _weekRangeLabel(context, snap.weekMonday),
                      style: TextStyle(
                          fontSize: portalSp(context, 15),
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMuted),
                    ),
                    if (snap.aggregatedDayCount > 0 &&
                        snap.aggregatedDayCount < 7) ...[
                      const SizedBox(height: 8),
                      Text(
                        s.reportWeeklyPartialWeekHint(
                          _weekdayName(
                              context,
                              snap.weekMonday.add(
                                  Duration(days: snap.aggregatedDayCount - 1))),
                        ),
                        style: TextStyle(
                            fontSize: portalSp(context, 13),
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryPurple),
                      ),
                    ],
                    if (snap.aggregatedDayCount == 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        s.reportWeeklyFutureWeekHint,
                        style: TextStyle(
                            fontSize: portalSp(context, 13),
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      PhotoAvatar(
                        photoB64: photoB64,
                        photoUrl: photoUrl == null || photoUrl.isEmpty
                            ? null
                            : photoUrl,
                        radius: 26,
                        backgroundColor: AppTheme.softPurple,
                        fallback:
                            const Text('👶', style: TextStyle(fontSize: 30)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(babyName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 20)),
                            Text(ageAtEndOfWeek,
                                style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_error != null && snap == null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${s.reportWeeklyLoadErrorPrefix} $_error',
                            style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _load,
                            child: Text(s.gateRetry),
                          ),
                        ],
                      ),
                    ),
                  ] else if (snap == null)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_heroPurple, _heroPurple.withAlpha(210)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                              color: _heroPurple.withAlpha(60),
                              blurRadius: 20,
                              offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Icon(Icons.nightlight_round,
                                size: 72, color: Colors.amber.withAlpha(220)),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.reportWeeklySummaryTitle,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _heroParagraph(s, snap, babyName),
                                style: const TextStyle(
                                    color: Colors.white,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _highlightLine(s, snap),
                                style: TextStyle(
                                    color: Colors.white.withAlpha(245),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(s.reportWeeklyTrendsTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 17)),
                    const SizedBox(height: 10),
                    _whiteCard(child: _buildTrendsList(s, snap)),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.lavender,
                          foregroundColor: AppTheme.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999)),
                        ),
                        onPressed: () {
                          pushPortalPage<void>(
                              context, WeekDetailsPage(snapshot: snap));
                        },
                        child: Text(s.reportWeeklySeeFullDetails,
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }

  /// Lista de linhas de tendência — agora mostra sempre o valor absoluto desta
  /// semana (média/dia ou ganho de peso). O `±%` vs semana anterior aparece
  /// como badge pequeno só quando há comparação fiável; caso contrário a linha
  /// continua "preenchida" (sem `N/A` por todo o lado).
  Widget _buildTrendsList(S s, WeeklyReportSnapshot snap) {
    final agg = snap.aggregatedDayCount.clamp(0, 7);
    final currSlice = agg <= 0
        ? const <DailySummary>[]
        : snap.currentWeekDays
            .sublist(0, agg.clamp(0, snap.currentWeekDays.length));
    final avgSleepH = WeeklyReportService.avgSleepHours(currSlice);

    final sleepValue = WeeklyReportService.formatHoursMinutes(avgSleepH);
    final feedsValue =
        s.reportWeeklyAvgFeedsDay(snap.avgDailyFeedings.toStringAsFixed(1));
    final diapersValue =
        s.reportWeeklyAvgDiapersDay(snap.avgDailyDiapers.toStringAsFixed(1));
    final wDelta = snap.weightDeltaGramsThisWeek;
    final weightValue =
        wDelta == null ? '—' : '${wDelta > 0 ? '+' : ''}${wDelta}g';

    return Column(
      children: [
        _trendRow(
          context,
          icon: Icons.nightlight_round,
          iconColor: AppTheme.primaryPurple,
          label: s.shortcutSleep,
          mainValue: sleepValue,
          comparison: _comparisonBadge(snap.sleepBand, snap.sleepPctVsPrev),
          comparisonColor: _trendColor(snap.sleepBand),
          comparisonIcon: _trendIcon(snap.sleepBand),
          subtitle: s.reportWeeklyAvgWeekLabel,
        ),
        const Divider(height: 20),
        _trendRow(
          context,
          icon: Icons.restaurant_outlined,
          iconColor: const Color(0xFFE08A3E),
          label: s.reportTabFeedings,
          mainValue: feedsValue,
          comparison: _comparisonBadge(snap.feedingBand, snap.feedingPctVsPrev),
          comparisonColor: _trendColor(snap.feedingBand),
          comparisonIcon: _trendIcon(snap.feedingBand),
          subtitle: _trendLabel(s, snap.feedingBand, forWeight: false),
        ),
        const Divider(height: 20),
        _trendRow(
          context,
          icon: Icons.baby_changing_station_rounded,
          iconColor: AppTheme.babyBlue,
          label: s.shortcutDiaper,
          mainValue: diapersValue,
          comparison: _comparisonBadge(snap.diaperBand, snap.diaperPctVsPrev),
          comparisonColor: _trendColor(snap.diaperBand),
          comparisonIcon: _trendIcon(snap.diaperBand),
          subtitle: snap.diaperBand == WeeklyTrendBand.improved
              ? s.reportWeeklyTrendLabelIncreased
              : _trendLabel(s, snap.diaperBand, forWeight: false),
        ),
        const Divider(height: 20),
        _trendRow(
          context,
          icon: Icons.monitor_weight_outlined,
          iconColor: AppTheme.secondary,
          label: s.growth,
          mainValue: weightValue,
          comparison: null,
          comparisonColor: _trendColor(snap.weightBand),
          comparisonIcon: _trendIcon(snap.weightBand),
          subtitle: _trendLabel(s, snap.weightBand, forWeight: true),
        ),
      ],
    );
  }

  Widget _trendRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String mainValue,
    required String subtitle,
    String? comparison,
    Color? comparisonColor,
    IconData? comparisonIcon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: iconColor.withAlpha(36),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 15)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              mainValue,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppTheme.textPrimary),
            ),
            if (comparison != null) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (comparisonIcon != null)
                    Icon(comparisonIcon,
                        color: comparisonColor ?? AppTheme.textMuted, size: 14),
                  if (comparisonIcon != null) const SizedBox(width: 2),
                  Text(
                    comparison,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: comparisonColor ?? AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}
