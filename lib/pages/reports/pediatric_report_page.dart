import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../models/pediatric_report_snapshot.dart';
import '../../services/pediatric_report_service.dart';
import '../../services/premium/feature_access.dart';
import '../../services/weekly_report_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/measurement_format.dart';
import '../../utils/memory_share_transport.dart';
import '../../utils/pediatric_report_pdf.dart';
import '../../utils/pediatric_report_symptom_lines.dart';
import '../../utils/portal_layout.dart';
import '../premium/premium_paywall_screen.dart';
import 'report_page_shell.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _mondayOfWeek(DateTime day) {
  final local = _dateOnly(day);
  return local.subtract(Duration(days: local.weekday - DateTime.monday));
}

/// Relatório clínico para o pediatra — resumo da semana, observações e PDF.
class PediatricReportPage extends StatefulWidget {
  const PediatricReportPage({super.key, required this.anchorDay});

  final DateTime anchorDay;

  @override
  State<PediatricReportPage> createState() => _PediatricReportPageState();
}

class _PediatricReportPageState extends State<PediatricReportPage> {
  PediatricReportSnapshot? _snapshot;
  Object? _error;
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  final _babyCtrl = CurrentBabyController.instance;
  final _notesCtrl = TextEditingController();
  Timer? _notesDebounce;
  static const _clinicalPurple = Color(0xFF4A3F6B);
  static const _cardBorder = Color(0xFFE8E4F5);
  static const _btnFill = Color(0xFFD9D3F0);

  @override
  void initState() {
    super.initState();
    final anchor = _dateOnly(widget.anchorDay);
    final mon = _mondayOfWeek(anchor);
    _rangeStart = mon;
    _rangeEnd = mon.add(const Duration(days: 6));
    _babyCtrl.addListener(_onBaby);
    _loadSnapshot();
  }

  @override
  void dispose() {
    _notesDebounce?.cancel();
    _notesCtrl.dispose();
    _babyCtrl.removeListener(_onBaby);
    super.dispose();
  }

  void _onBaby() => _loadSnapshot();

  Future<void> _loadNotes() async {
    final id = _babyCtrl.currentBabyId;
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    final snap = _snapshot;
    if (snap == null) return;
    final key =
        'pediatric_notes_${id}_${snap.periodStart.toIso8601String().substring(0, 10)}_${snap.periodEndInclusive.toIso8601String().substring(0, 10)}';
    final t = prefs.getString(key);
    if (mounted) _notesCtrl.text = t ?? '';
  }

  Future<void> _saveNotes() async {
    final id = _babyCtrl.currentBabyId;
    final snap = _snapshot;
    if (id == null || snap == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key =
        'pediatric_notes_${id}_${snap.periodStart.toIso8601String().substring(0, 10)}_${snap.periodEndInclusive.toIso8601String().substring(0, 10)}';
    await prefs.setString(key, _notesCtrl.text.trim());
  }

  Future<void> _loadSnapshot() async {
    final id = _babyCtrl.currentBabyId;
    if (id == null) {
      if (mounted) setState(() => _snapshot = null);
      return;
    }
    try {
      final snap = await PediatricReportService.load(
        babyId: id,
        periodStart: _rangeStart,
        periodEndInclusive: _rangeEnd,
      );
      if (mounted) {
        setState(() {
          _snapshot = snap;
          _error = null;
          _rangeStart = snap.periodStart;
          _rangeEnd = snap.periodEndInclusive;
        });
        await _loadNotes();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null && mounted) {
      setState(() {
        _rangeStart = _dateOnly(picked.start);
        _rangeEnd = _dateOnly(picked.end);
      });
      await _loadSnapshot();
    }
  }

  String _periodRangeLabel(BuildContext context, DateTime start, DateTime end) {
    final loc = Localizations.localeOf(context).toString();
    try {
      if (start.year == end.year &&
          start.month == end.month &&
          start.day == end.day) {
        return DateFormat.yMMMd(loc).format(start);
      }
      if (start.year == end.year && start.month == end.month) {
        return '${start.day} – ${DateFormat('d MMMM y', loc).format(end)}';
      }
      return '${DateFormat.yMMMd(loc).format(start)} – ${DateFormat.yMMMd(loc).format(end)}';
    } catch (_) {
      return '${start.day}/${start.month} – ${end.day}/${end.month}/${end.year}';
    }
  }

  String _sleepPattern(S s, PediatricReportSnapshot snap) {
    switch (snap.sleepPatternKey) {
      case 'stable':
        return s.reportPediatricSleepPatternStable;
      case 'fragmented':
        return s.reportPediatricSleepPatternFragmented;
      default:
        return s.reportPediatricSleepPatternModerate;
    }
  }

  String _weightGainLabel(PediatricReportSnapshot snap) {
    final g = snap.weightDeltaGrams;
    if (g == null) return '—';
    if (g >= 0) return '+$g g';
    return '$g g';
  }

  String _heightGainLabel(PediatricReportSnapshot snap) {
    final cm = snap.heightDeltaCm;
    if (cm == null) return '—';
    final text = MeasurementFormat.length(cm.abs(), decimalsCm: 1);
    if (cm > 0) return '+$text';
    if (cm < 0) return '-$text';
    return text;
  }

  PediatricReportPdfStrings _pdfStrings(S s) {
    return PediatricReportPdfStrings(
      title: s.reportPediatricPdfTitle,
      periodLabel: s.reportPediatricPdfPeriod,
      sectionBaby: s.reportPediatricSectionGeneral,
      sectionSummary: s.reportPediatricSectionSummary,
      sectionSleep: s.reportPediatricSectionSleep,
      sectionFeeding: s.reportPediatricSectionFeeding,
      sectionSymptoms: s.reportPediatricSectionSymptoms,
      sectionObservations: s.reportPediatricSectionObservations,
      labelName: s.reportPediatricLabelName,
      labelBirth: s.reportPediatricLabelBirth,
      labelAge: s.reportPediatricLabelAge,
      labelWeightStart: s.reportPediatricWeightStart,
      labelWeightEnd: s.reportPediatricWeightEnd,
      labelWeightGain: s.reportPediatricWeightGain,
      labelHeightStart: s.reportPediatricHeightStart,
      labelHeightEnd: s.reportPediatricHeightEnd,
      labelHeightGain: s.reportPediatricHeightGain,
      labelHeight: s.reportPediatricLabelHeight,
      labelAvgFeeds: s.reportPediatricAvgFeeds,
      labelAvgSleep: s.reportPediatricAvgSleep,
      labelAvgDiapers: s.reportPediatricAvgDiapers,
      labelVaccines: s.reportPediatricVaccines,
      labelSleepAvgDay: s.reportPediatricSleepAvgDaily,
      labelSleepAwakenings: s.reportPediatricSleepAwakenings,
      labelSleepPattern: s.reportPediatricSleepPattern,
      labelSleepLongest: s.reportPediatricSleepLongest,
      labelFeedBreast: s.reportPediatricFeedingBreast,
      labelFeedFormula: s.reportPediatricFeedingFormula,
      labelFeedSolid: s.reportPediatricFeedingSolid,
      labelFeedSessions: s.reportPediatricFeedingSessions,
      labelAvgDuration: s.reportPediatricFeedingAvgDur,
      symptomDetailsEmpty: s.reportPediatricStructuredSymptomsEmpty,
      na: s.reportPediatricNa,
      footerDisclaimer: s.reportPediatricPdfFooter,
      noneRegistered: s.reportPediatricNone,
    );
  }

  Future<Uint8List> _buildPdfBytes(S s) async {
    final snap = _snapshot!;
    final babyRow = _babyCtrl.currentBabyRow;
    final birthRaw = babyRow?['birth_date'] as String?;
    final birth = DateTime.tryParse(birthRaw ?? '');
    final loc = Localizations.localeOf(context).toString();
    final name = (babyRow?['name'] as String?)?.trim();
    final babyName =
        (name == null || name.isEmpty) ? s.placeholderBabyName : name;
    final birthFmt = birth == null ? '—' : DateFormat.yMd(loc).format(birth);
    final periodEnd = snap.periodEndInclusive;
    final ageLine = birth == null ? '—' : s.babyAgeLabel(birth, periodEnd);
    final periodLine =
        _periodRangeLabel(context, snap.periodStart, snap.periodEndInclusive);

    final symptomBlocks = PediatricReportSymptomLines.buildBlocks(
        s, snap.symptomOccurrencesByKind, loc);

    return buildPediatricReportPdf(
      snap: snap,
      babyName: babyName,
      birthFormatted: birthFmt,
      ageLine: ageLine,
      periodRangeFormatted: periodLine,
      parentsNotes: _notesCtrl.text,
      weightStartFmt: MeasurementFormat.weight(snap.weightStartKg),
      weightEndFmt: MeasurementFormat.weight(snap.weightEndKg),
      weightGainFmt: _weightGainLabel(snap),
      heightStartFmt: MeasurementFormat.length(snap.heightStartCm),
      heightEndFmt: MeasurementFormat.length(snap.heightEndCm),
      heightGainFmt: _heightGainLabel(snap),
      heightFmt: MeasurementFormat.length(snap.heightCm),
      sleepPatternText: _sleepPattern(s, snap),
      symptomDetailBlocks: symptomBlocks,
      str: _pdfStrings(s),
    );
  }

  Future<void> _sharePdf(S s) async {
    if (!FeatureAccess.canExportPdf) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.plusSnackLockedFeature)));
      await openPremiumPaywall(context);
      return;
    }
    final snap = _snapshot;
    if (snap == null) return;
    try {
      final bytes = await _buildPdfBytes(s);
      final stamp =
          '${DateFormat('yyyyMMdd').format(snap.periodStart)}_${DateFormat('yyyyMMdd').format(snap.periodEndInclusive)}';
      await shareTempBytes(
          bytes, 'facebaby_pediatria_$stamp.pdf', 'application/pdf');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _printPdf(S s) async {
    if (!FeatureAccess.canExportPdf) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.plusSnackLockedFeature)));
      await openPremiumPaywall(context);
      return;
    }
    final snap = _snapshot;
    if (snap == null) return;
    try {
      final bytes = await _buildPdfBytes(s);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _emailSummary(S s) async {
    if (!FeatureAccess.canExportPdf) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.plusSnackLockedFeature)));
      await openPremiumPaywall(context);
      return;
    }
    final snap = _snapshot;
    if (snap == null) return;
    final babyRow = _babyCtrl.currentBabyRow;
    final name = (babyRow?['name'] as String?)?.trim() ?? s.placeholderBabyName;
    final subject = Uri.encodeComponent('${s.reportPediatricPdfTitle} — $name');
    final body = Uri.encodeComponent(
      '${s.reportPediatricPdfPeriod} ${_periodRangeLabel(context, snap.periodStart, snap.periodEndInclusive)}\n\n${_notesCtrl.text.trim()}',
    );
    final uri = Uri.parse('mailto:?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _whatsappShare(S s) async {
    await _sharePdf(s);
  }

  Widget _clinicalCard(
      {required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _clinicalPurple)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value, S s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(label,
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: portalSp(context, 14))),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: portalSp(context, 14),
                  color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDayShort(DateTime d) {
    final loc = Localizations.localeOf(context).toString();
    try {
      return DateFormat.yMd(loc).format(d);
    } catch (_) {
      return '${d.day}/${d.month}/${d.year}';
    }
  }

  Widget _rangeFilterCard(S s) {
    final rangeLine = _periodRangeLabel(context, _rangeStart, _rangeEnd);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _cardBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _pickDateRange,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.reportPediatricFilterHint,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: portalSp(context, 13),
                          color: _clinicalPurple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rangeLine,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: portalSp(context, 15),
                          height: 1.25,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (_rangeStart.year == _rangeEnd.year &&
                                _rangeStart.month == _rangeEnd.month &&
                                _rangeStart.day == _rangeEnd.day)
                            ? '${s.reportPediatricDateFrom} ${_fmtDayShort(_rangeStart)}'
                            : '${s.reportPediatricDateFrom} ${_fmtDayShort(_rangeStart)} · ${s.reportPediatricDateTo} ${_fmtDayShort(_rangeEnd)}',
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: portalSp(context, 11.5),
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.reportPediatricFilterMaxDaysHint,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.edit_calendar_outlined,
                    color: _clinicalPurple, size: 24),
              ],
            ),
          ),
        ),
      ),
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
    final babyName =
        (name == null || name.isEmpty) ? s.placeholderBabyName : name;
    final loc = Localizations.localeOf(context).toString();
    final birthFmt = birth == null ? '—' : DateFormat.yMd(loc).format(birth);

    final ageRefEnd = snap == null ? _rangeEnd : snap.periodEndInclusive;
    final ageLine = birth == null ? '—' : s.babyAgeLabel(birth, ageRefEnd);

    final reportBg = reportScaffoldBackground();

    return Scaffold(
      backgroundColor: reportBg,
      appBar: AppBar(
        backgroundColor: reportBg,
        surfaceTintColor: reportBg,
        elevation: 0,
        foregroundColor: _clinicalPurple,
        title: Text(s.reportPediatricScreenTitle,
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: _clinicalPurple)),
        actions: [
          IconButton(
            onPressed: bid == null ? null : _pickDateRange,
            icon: const Icon(Icons.date_range_rounded),
            tooltip: s.reportPediatricPickRange,
          ),
        ],
      ),
      body: bid == null
          ? Center(child: Text(s.feedingNoBabyHint))
          : _error != null
              ? Center(child: SelectableText('$_error'))
              : RefreshIndicator(
                  onRefresh: _loadSnapshot,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                        AppTheme.pageHPadding, 8, AppTheme.pageHPadding, 140),
                    children: [
                      _rangeFilterCard(s),
                      if (snap == null)
                        const SizedBox(
                          height: 200,
                          child: Center(
                              child: CircularProgressIndicator.adaptive()),
                        )
                      else ...[
                        Text(
                          babyName,
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: portalSp(context, 20),
                              color: _clinicalPurple),
                        ),
                        Text(ageLine,
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 18),
                        _clinicalCard(
                          title: s.reportPediatricSectionGeneral,
                          children: [
                            _row(s.reportPediatricLabelName, babyName, s),
                            _row(s.reportPediatricLabelAge, ageLine, s),
                            _row(s.reportPediatricLabelBirth, birthFmt, s),
                            _row(s.reportPediatricLabelWeightCurrent,
                                MeasurementFormat.weight(snap.weightEndKg), s),
                            _row(s.reportPediatricLabelHeight,
                                MeasurementFormat.length(snap.heightCm), s),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _clinicalCard(
                          title: s.reportPediatricSectionSummary,
                          children: [
                            _row(
                                s.reportPediatricWeightStart,
                                MeasurementFormat.weight(snap.weightStartKg),
                                s),
                            _row(s.reportPediatricWeightEnd,
                                MeasurementFormat.weight(snap.weightEndKg), s),
                            _row(s.reportPediatricWeightGain,
                                _weightGainLabel(snap), s),
                            _row(
                                s.reportPediatricHeightStart,
                                MeasurementFormat.length(snap.heightStartCm),
                                s),
                            _row(s.reportPediatricHeightEnd,
                                MeasurementFormat.length(snap.heightEndCm), s),
                            _row(s.reportPediatricHeightGain,
                                _heightGainLabel(snap), s),
                            _row(s.reportPediatricAvgFeeds,
                                snap.avgFeedingsPerDay.toStringAsFixed(1), s),
                            _row(
                                s.reportPediatricAvgSleep,
                                WeeklyReportService.formatHoursMinutes(
                                    snap.avgSleepHoursPerDay),
                                s),
                            _row(s.reportPediatricAvgDiapers,
                                snap.avgDiapersPerDay.toStringAsFixed(1), s),
                            _row(
                              s.reportPediatricVaccines,
                              snap.vaccinesInPeriodLines.isEmpty
                                  ? s.reportPediatricNone
                                  : snap.vaccinesInPeriodLines.join('\n'),
                              s,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _clinicalCard(
                          title: s.reportPediatricSectionSleep,
                          children: [
                            _row(
                                s.reportPediatricSleepAvgDaily,
                                WeeklyReportService.formatHoursMinutes(
                                    snap.avgSleepHoursPerDay),
                                s),
                            _row(
                              s.reportPediatricSleepAwakenings,
                              snap.sleepAwakeningsAvg <= 0
                                  ? '—'
                                  : snap.sleepAwakeningsAvg.toStringAsFixed(1),
                              s,
                            ),
                            if (snap.hasSleepPatternBasis)
                              _row(s.reportPediatricSleepPattern,
                                  _sleepPattern(s, snap), s),
                            _row(
                                s.reportPediatricSleepLongest,
                                WeeklyReportService.formatHoursMinutes(
                                    snap.longestSleepSec / 3600.0),
                                s),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _clinicalCard(
                          title: s.reportPediatricSectionFeeding,
                          children: [
                            _row(
                              '${s.reportPediatricFeedingBreast} (${s.reportPediatricFeedingSessions})',
                              '${snap.breastfeedingSessions} · ${s.reportPediatricFeedingAvgDur}: ${snap.avgBreastMinutes == null ? '—' : '${snap.avgBreastMinutes!.round()} min'}',
                              s,
                            ),
                            _row(
                              '${s.reportPediatricFeedingFormula} (${s.reportPediatricFeedingSessions})',
                              '${snap.formulaSessions} · ${s.reportPediatricFeedingAvgDur}: ${snap.avgFormulaMinutes == null ? '—' : '${snap.avgFormulaMinutes!.round()} min'}',
                              s,
                            ),
                            _row(
                              '${s.reportPediatricFeedingSolid} (${s.reportPediatricFeedingSessions})',
                              '${snap.solidFoodSessions} · ${s.reportPediatricFeedingAvgDur}: ${snap.avgSolidMinutes == null ? '—' : '${snap.avgSolidMinutes!.round()} min'}',
                              s,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _clinicalCard(
                          title: s.reportPediatricSectionSymptoms,
                          children: [
                            if (!PediatricReportSymptomLines.hasAnyOccurrence(
                                snap.symptomOccurrencesByKind))
                              Text(
                                s.reportPediatricStructuredSymptomsEmpty,
                                style: TextStyle(
                                  fontSize: portalSp(context, 13),
                                  color: AppTheme.textMuted,
                                  height: 1.35,
                                ),
                              )
                            else
                              ...PediatricReportSymptomLines.buildBlocks(
                                      s, snap.symptomOccurrencesByKind, loc)
                                  .map(
                                (block) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      block,
                                      style: TextStyle(
                                        fontSize: portalSp(context, 13),
                                        height: 1.4,
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _clinicalCard(
                          title: s.reportPediatricSectionObservations,
                          children: [
                            TextField(
                              controller: _notesCtrl,
                              minLines: 4,
                              maxLines: 10,
                              style: TextStyle(
                                  fontSize: portalSp(context, 14),
                                  height: 1.35),
                              decoration: InputDecoration(
                                hintText: s.reportPediatricObsHint,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: _cardBorder)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: _clinicalPurple),
                                ),
                              ),
                              onChanged: (_) {
                                _notesDebounce?.cancel();
                                _notesDebounce = Timer(
                                    const Duration(milliseconds: 400),
                                    _saveNotes);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(s.reportPediatricScreenFootnote,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                                height: 1.35)),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _lavenderButton(
                                label: s.reportPediatricBtnShare,
                                onTap: () => _sharePdf(s),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _lavenderButton(
                                label: s.reportPediatricBtnExportPdf,
                                onTap: () => _sharePdf(s),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                                child: _outlineBtn(
                                    icon: Icons.print_rounded,
                                    label: s.reportPediatricBtnPrint,
                                    onTap: () => _printPdf(s))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _outlineBtn(
                                    icon: Icons.email_outlined,
                                    label: s.reportPediatricBtnEmail,
                                    onTap: () => _emailSummary(s))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _outlineBtn(
                                icon: Icons.chat_rounded,
                                label: s.reportPediatricBtnWhatsApp,
                                onTap: () => _whatsappShare(s),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _lavenderButton({required String label, required VoidCallback onTap}) {
    return Material(
      color: _btnFill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: _clinicalPurple)),
          ),
        ),
      ),
    );
  }

  Widget _outlineBtn(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: _clinicalPurple),
      label: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: _clinicalPurple)),
      style: OutlinedButton.styleFrom(
        foregroundColor: _clinicalPurple,
        side: const BorderSide(color: _cardBorder),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }
}
