import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../models/daily_report_snapshot.dart';
import '../../services/daily_report_service.dart'
    show DailyReportService, formatTimeHm;
import '../../theme/app_theme.dart';
import '../../utils/portal_layout.dart';
import '../../utils/portal_page_route.dart';
import '../../widgets/photo_avatar.dart';
import 'day_details_page.dart';
import 'report_page_shell.dart';

/// Relatório diário — cartões resumo; detalhes em [DayDetailsPage].
class DailyReportPage extends StatefulWidget {
  const DailyReportPage({super.key, required this.initialDay});

  final DateTime initialDay;

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  late DateTime _day;
  DailyReportSnapshot? _snapshot;
  Object? _error;
  final _babyCtrl = CurrentBabyController.instance;

  @override
  void initState() {
    super.initState();
    final n = widget.initialDay;
    _day = DateTime(n.year, n.month, n.day);
    _babyCtrl.addListener(_onBaby);
    _load();
  }

  @override
  void dispose() {
    _babyCtrl.removeListener(_onBaby);
    super.dispose();
  }

  void _onBaby() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final id = _babyCtrl.currentBabyId;
    if (id == null) {
      if (mounted) setState(() => _snapshot = null);
      return;
    }
    try {
      final snap = await DailyReportService.load(babyId: id, calendarDay: _day);
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

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null && mounted) {
      setState(() => _day = DateTime(picked.year, picked.month, picked.day));
      await _load();
    }
  }

  String _formatHeaderDate(BuildContext context) {
    final loc = Localizations.localeOf(context).toString();
    try {
      return DateFormat.yMMMMd(loc).format(_day);
    } catch (_) {
      return DateFormat.yMMMMd().format(_day);
    }
  }

  String _sleepQualityLabel(S s, DailyReportSnapshot snap) {
    final c = snap.sleepQualityCounts;
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

  void _openDetails() {
    final snap = _snapshot;
    if (snap == null) return;
    pushPortalPage<void>(
      context,
      DayDetailsPage(
        calendarDay: _day,
        snapshot: snap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final babyRow = _babyCtrl.currentBabyRow;
    final bid = _babyCtrl.currentBabyId;
    final snap = _snapshot;

    final birthRaw = babyRow?['birth_date'] as String?;
    final birth = DateTime.tryParse(birthRaw ?? '');
    final name = (babyRow?['name'] as String?)?.trim();
    final babyName =
        (name == null || name.isEmpty) ? s.placeholderBabyName : name;
    final ageAtDay = birth == null ? '—' : s.babyAgeLabel(birth, _day);
    final photoB64 = babyRow?['photo_b64'] as String?;
    final photoUrl = (babyRow?['photo_url'] as String?)?.trim();

    final reportBg = reportScaffoldBackground();

    return Scaffold(
      backgroundColor: reportBg,
      appBar: AppBar(
        backgroundColor: reportBg,
        surfaceTintColor: reportBg,
        elevation: 0,
        title: Text(s.reportDailyScreenTitle,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: s.reportDailyPickDayTooltip,
            onPressed: _pickDay,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      body: bid == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(s.feedingNoBabyHint, textAlign: TextAlign.center),
              ),
            )
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
                          _formatHeaderDate(context),
                          style: TextStyle(
                            fontSize: portalSp(context, 18),
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                          onPressed: _pickDay,
                          icon: const Icon(Icons.event_rounded,
                              color: AppTheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      PhotoAvatar(
                        photoB64: photoB64,
                        photoUrl: photoUrl == null || photoUrl.isEmpty
                            ? null
                            : photoUrl,
                        radius: 28,
                        backgroundColor: AppTheme.softPurple,
                        fallback:
                            const Text('👶', style: TextStyle(fontSize: 32)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              babyName,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary),
                            ),
                            Text(
                              ageAtDay,
                              style: TextStyle(
                                  fontSize: portalSp(context, 14),
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text('$_error',
                        style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 22),
                  if (snap == null)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator()))
                  else ...[
                    _SummaryCard(
                      icon: Icons.nightlight_round,
                      iconColor: const Color(0xFF9D8AF2),
                      title: s.shortcutSleep,
                      subtitle: s.reportDailySubtitleTotalSleep,
                      value: snap.summary.sleep,
                      extraLine: s.reportDailySubtitleSleepQuality,
                      extraValue: _sleepQualityLabel(s, snap),
                      extraLine2: s.reportDailySubtitleLongestStretch,
                      extraValue2: snap.longestSleepSessionSec > 0
                          ? DailyReportService.formatDurationShort(
                              snap.longestSleepSessionSec)
                          : '—',
                      onTap: _openDetails,
                    ),
                    const SizedBox(height: 12),
                    _SummaryCard(
                      icon: Icons.restaurant_outlined,
                      iconColor: const Color(0xFFE08A3E),
                      title: s.reportTabFeedings,
                      subtitle: s.reportDailySubtitleFeedTotal,
                      value: '${snap.summary.feedings}',
                      extraLine: s.reportDailySubtitleFeedAvg,
                      extraValue: snap.avgFeedingDurationSec > 0
                          ? DailyReportService.formatDurationShort(
                              snap.avgFeedingDurationSec)
                          : '—',
                      extraLine2: s.reportDailySubtitleFeedLast,
                      extraValue2: formatTimeHm(snap.lastFeedingEndedAt),
                      onTap: _openDetails,
                    ),
                    const SizedBox(height: 12),
                    _SummaryCard(
                      icon: Icons.baby_changing_station_rounded,
                      iconColor: AppTheme.babyBlue,
                      title: s.shortcutDiaper,
                      subtitle: s.reportDailySubtitleDiaperTotal,
                      value: '${snap.summary.diapers}',
                      extraLine: s.reportDailySubtitleDiaperWet,
                      extraValue: '${snap.summary.diaperPee}',
                      extraLine2: s.reportDailySubtitleDiaperDirty,
                      extraValue2: '${snap.summary.diaperPoo}',
                      onTap: _openDetails,
                    ),
                    const SizedBox(height: 12),
                    _SummaryCard(
                      icon: Icons.monitor_weight_outlined,
                      iconColor: AppTheme.primaryPurple,
                      title: s.growth,
                      subtitle: s.reportDailySubtitleWeightLast,
                      value: snap.summary.weight,
                      onTap: _openDetails,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
    this.extraLine,
    this.extraValue,
    this.extraLine2,
    this.extraValue2,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;
  final String? extraLine;
  final String? extraValue;
  final String? extraLine2;
  final String? extraValue2;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withAlpha(22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(38),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w600)),
                      if (extraLine != null && extraValue != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '$extraLine · $extraValue',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary),
                          maxLines: 2,
                        ),
                      ],
                      if (extraLine2 != null && extraValue2 != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$extraLine2 · $extraValue2',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted.withAlpha(230)),
                          maxLines: 2,
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: AppTheme.textPrimary),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.black.withAlpha(70)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
