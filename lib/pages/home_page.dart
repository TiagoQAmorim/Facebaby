import 'dart:async' show Timer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../controllers/current_baby_controller.dart';
import '../controllers/sleep_timer_controller.dart';
import '../services/reminder_monitor.dart';
import '../models/baby.dart';
import '../models/consultation_record.dart';
import '../models/daily_summary.dart';
import '../models/home_day_snapshot.dart';
import '../models/vaccine_record.dart';
import '../i18n/app_i18n.dart';
import '../services/app_database.dart';
import '../services/health_calendar_events.dart';
import '../services/diaper_events.dart';
import '../services/feeding_events.dart';
import '../services/growth_events.dart';
import '../services/sleep_events.dart';
import '../services/sleep_routine.dart';
import '../services/development_leaps_service.dart';
import '../utils/measurement_format.dart';
import '../services/measurement_units_prefs.dart';
import '../services/mock_baby_service.dart';
import '../services/baby_daily_tips_service.dart';
import '../services/home_prefs.dart';
import '../services/firebase/cloud_bootstrap_sync.dart';
import '../services/firebase/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/consultation_detail_sheet.dart';
import '../widgets/language_picker.dart';
import '../widgets/photo_avatar.dart';
import '../widgets/section_title.dart';
import '../utils/portal_layout.dart';
import '../app/shell_nested_nav.dart';
import 'diaper_page.dart';
import 'feeding_hub_page.dart';
import 'growth_dashboard_page.dart';
import 'notifications_inbox_page.dart';
import 'sleep_page.dart';
import 'vaccines_page.dart';
import 'development_leaps_page.dart';

/// Mesmo intervalo dos lembretes de fralda (3 h 30 min).
const int _kHomeBannerDiaperOverdueMin = 210;

class HomePage extends StatefulWidget {
  final Baby baby;
  final MockBabyService babyService;
  final VoidCallback onOpenQuickRegister;
  final VoidCallback? onPickBaby;
  final String? motherName;
  final String? motherPhotoB64;
  final VoidCallback? onPickMotherPhoto;
  final VoidCallback? onPickBabyPhoto;

  const HomePage({
    super.key,
    required this.baby,
    required this.babyService,
    required this.onOpenQuickRegister,
    this.onPickBaby,
    this.motherName,
    this.motherPhotoB64,
    this.onPickMotherPhoto,
    this.onPickBabyPhoto,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _sameCalendarDate(DateTime? a, DateTime? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _HomePageState extends State<HomePage> {
  late DateTime _selectedDay;
  /// Peito ou mamadeira: horário de término mais recente (hoje).
  DateTime? _lastBreastOrBottleEndedAt;

  /// Última troca registada (`changed_at`) — hoje; vem da BD.
  DateTime? _lastDiaperChangedAt;

  /// Fim do último período de sono registado (`ended_at` mais recente).
  DateTime? _lastSleepEndedAt;

  /// Resumo alimentação / fraldas / sono / peso — dados reais da BD (dia do calendário selecionado).
  DailySummary? _dbDailySummary;

  /// Últimos horários **nesse dia civil** (hints dos 4 quadrados).
  DateTime? _summaryHintFeedEnd;
  DateTime? _summaryHintDiaperAt;
  DateTime? _summaryHintSleepEnd;

  /// Vacinas com data de aplicação no dia civil do resumo.
  List<VaccineRecord> _dayVaccines = <VaccineRecord>[];
  List<VaccineRecord> _dayVaccinesDue = <VaccineRecord>[];

  /// Consultas com horário no dia civil do resumo.
  List<ConsultationRecord> _dayConsultations = <ConsultationRecord>[];

  /// Próxima consulta futura (para o banner do cartão do bebé).
  ConsultationRecord? _bannerNextConsultation;

  @override
  void initState() {
    super.initState();
    _selectedDay = _dateOnly(DateTime.now());
    // O [Navigator] do separador Início não reconstrói o filho quando só muda o mapa do bebé na BD;
    // ouvimos o controller para atualizar foto / dados sem depender de [widget.baby] stale.
    CurrentBabyController.instance.addListener(_onCurrentBabyUiChanged);
    CurrentBabyController.instance.addListener(_onHomeFeedSourcesChanged);
    FeedingEvents.revision.addListener(_onHomeFeedSourcesChanged);
    DiaperEvents.revision.addListener(_onHomeFeedSourcesChanged);
    SleepEvents.revision.addListener(_onHomeFeedSourcesChanged);
    GrowthEvents.revision.addListener(_onHomeFeedSourcesChanged);
    HealthCalendarEvents.revision.addListener(_onHomeFeedSourcesChanged);
    HomePrefs.feedingAlertsEnabled.addListener(_onFeedingIntervalPrefsChanged);
    HomePrefs.feedingAlertIntervalMinutes.addListener(_onFeedingIntervalPrefsChanged);
    HomePrefs.sleepAlertsEnabled.addListener(_onFeedingIntervalPrefsChanged);
    // Unidades: ao alterar, recarrega o resumo para recalcular labels (ex.: peso do dia).
    MeasurementUnitsPrefs.weight.addListener(_onHomeUnitsChanged);
    MeasurementUnitsPrefs.length.addListener(_onHomeUnitsChanged);
    MeasurementUnitsPrefs.liquid.addListener(_onHomeUnitsChanged);
    MeasurementUnitsPrefs.temperature.addListener(_onHomeUnitsChanged);
    _refreshRealtimeHomeMetricsFromDb();
  }

  void _onFeedingIntervalPrefsChanged() {
    if (mounted) setState(() {});
  }

  void _onCurrentBabyUiChanged() {
    if (!mounted) return;
    setState(() {});
    _refreshRealtimeHomeMetricsFromDb();
  }

  void _onHomeFeedSourcesChanged() {
    _refreshRealtimeHomeMetricsFromDb();
  }

  /// Foto do bebé na BD (o [Baby] vindo do [MainShell] pode ficar stale dentro do [Navigator]).
  String? get _liveBabyPhotoB64 {
    final row = CurrentBabyController.instance.currentBabyRow;
    if (row != null) return row['photo_b64'] as String?;
    return widget.baby.photoB64;
  }

  String? get _liveBabyPhotoUrl {
    final row = CurrentBabyController.instance.currentBabyRow;
    final uRow = (row?['photo_url'] as String?)?.trim();
    if (uRow != null && uRow.isNotEmpty) return uRow;
    final w = widget.baby.photoUrl?.trim();
    return (w == null || w.isEmpty) ? null : w;
  }

  String? get _liveMotherPhotoB64 {
    final row = CurrentBabyController.instance.currentMotherRow;
    if (row != null) return row['photo_b64'] as String?;
    return widget.motherPhotoB64;
  }

  String? get _liveMotherPhotoUrl =>
      (CurrentBabyController.instance.currentMotherRow?['photo_url'] as String?)?.trim();

  /// Nascimento na BD — necessário para dicas do JSON por idade (`baby_daily_tips_500.json`).
  DateTime? get _liveBabyBirthDate {
    final raw = CurrentBabyController.instance.currentBabyRow?['birth_date'] as String?;
    if (raw != null && raw.trim().isNotEmpty) {
      final d = DateTime.tryParse(raw.trim());
      if (d != null) return DateTime(d.year, d.month, d.day);
    }
    final b = widget.baby.birthDate;
    if (b != null) return DateTime(b.year, b.month, b.day);
    return null;
  }

  String get _liveBabyName {
    final n = (CurrentBabyController.instance.currentBabyRow?['name'] as String?)?.trim();
    if (n != null && n.isNotEmpty) return n;
    return widget.baby.name;
  }

  /// Próxima consulta a mostrar no banner (até 30 dias).
  ConsultationRecord? get _consultationForBanner {
    final c = _bannerNextConsultation;
    if (c == null) return null;
    final now = DateTime.now();
    if (!c.occurredAt.isAfter(now)) return null;
    // Only show on the consultation day, from 06:00 until the consultation time.
    final start = DateTime(c.occurredAt.year, c.occurredAt.month, c.occurredAt.day, 6);
    if (now.isBefore(start)) return null;
    if (DateTime(now.year, now.month, now.day) !=
        DateTime(c.occurredAt.year, c.occurredAt.month, c.occurredAt.day)) {
      return null;
    }
    return c;
  }

  Future<void> _onPullRefresh() async {
    // Evita corrida: durante `refresh()` o bebê atual pode ficar momentaneamente nulo,
    // o que fazia o resumo cair no fallback (0) após o primeiro pull-to-refresh.
    await CurrentBabyController.instance.refresh();
    await _refreshRealtimeHomeMetricsFromDb();
    ReminderMonitor.instance.onAppResumed();
  }

  Future<void> _refreshRealtimeHomeMetricsFromDb() async {
    final id = CurrentBabyController.instance.currentBabyId;
    if (id == null) {
      if (mounted) {
        setState(() {
          _lastBreastOrBottleEndedAt = null;
          _lastDiaperChangedAt = null;
          _lastSleepEndedAt = null;
          _dbDailySummary = null;
          _summaryHintFeedEnd = null;
          _summaryHintDiaperAt = null;
          _summaryHintSleepEnd = null;
          _dayVaccines = <VaccineRecord>[];
          _dayVaccinesDue = <VaccineRecord>[];
          _dayConsultations = <ConsultationRecord>[];
          _bannerNextConsultation = null;
        });
      }
      return;
    }
    final day = _dateOnly(_selectedDay);
    try {
      final results = await Future.wait<Object?>([
        AppDatabase.instance.latestBreastOrBottleFeedingEndedAt(babyId: id),
        AppDatabase.instance.latestDiaperChangedAt(babyId: id),
        AppDatabase.instance.latestCompletedSleepEnd(babyId: id),
        AppDatabase.instance.dailySummaryForHomePicker(babyId: id, calendarDay: day),
        AppDatabase.instance.latestBreastOrBottleFeedingEndedOnCalendarDay(babyId: id, calendarDay: day),
        AppDatabase.instance.latestDiaperChangedAtOnCalendarDay(babyId: id, calendarDay: day),
        AppDatabase.instance.latestCompletedSleepEndOnCalendarDay(babyId: id, calendarDay: day),
        AppDatabase.instance.listVaccinesOnCalendarDay(babyId: id, calendarDay: day),
        AppDatabase.instance.listVaccinesDueOnCalendarDay(babyId: id, calendarDay: day),
        AppDatabase.instance.listConsultationsOnCalendarDay(babyId: id, calendarDay: day),
        AppDatabase.instance.nextUpcomingConsultation(babyId: id),
      ]);
      if (!mounted) return;

      // Robust fallback: if local cache is empty/stale, try cloud for "last feed" and "last completed sleep".
      DateTime? lastFeed = results[0] as DateTime?;
      DateTime? lastSleep = results[2] as DateTime?;
      if (lastFeed == null || lastSleep == null) {
        final babyCloud = (CurrentBabyController.instance.currentBabyRow?['cloud_id'] as String?)?.trim();
        if (babyCloud != null && babyCloud.isNotEmpty) {
          try {
            if (lastFeed == null) {
              final rows = await FirestoreService.instance.listFeedings(babyCloud);
              DateTime? best;
              for (final r in rows) {
                final iso = (r['ended_at'] as String?)?.trim();
                final dt = iso == null ? null : DateTime.tryParse(iso);
                if (dt == null) continue;
                if (best == null || dt.isAfter(best)) best = dt;
              }
              lastFeed = best?.toLocal();
            }
            if (lastSleep == null) {
              final rows = await FirestoreService.instance.listSleepRecords(babyCloud);
              DateTime? best;
              for (final r in rows) {
                final iso = (r['ended_at'] as String?)?.trim();
                final dt = iso == null ? null : DateTime.tryParse(iso);
                if (dt == null) continue;
                if (best == null || dt.isAfter(best)) best = dt;
              }
              lastSleep = best?.toLocal();
            }
          } catch (_) {
            // ignore network errors; keep nulls
          }
        }
      }

      final vRows = results[7] as List<Map<String, Object?>>;
      final vDueRows = results[8] as List<Map<String, Object?>>;
      final cRows = results[9] as List<Map<String, Object?>>;
      final upcomingRow = results[10] as Map<String, Object?>?;

      var summary = results[3] as DailySummary;
      final hintFeedEnd = results[4] as DateTime?;
      if (await AppDatabase.instance.feedingRowsHaveLegacyCloudSubtypeBug(babyId: id)) {
        await CloudBootstrapSync.hydrateBabyContent(id, bypassThrottle: true);
        try {
          summary = await AppDatabase.instance.dailySummaryForHomePicker(babyId: id, calendarDay: day);
        } catch (_) {}
      }
      // Fallback robusto: se há "última mamada no dia" mas o resumo veio zerado,
      // re-calcula uma vez (evita 0 por corrida/lock de BD em refresh rápido).
      if (hintFeedEnd != null && summary.feedings == 0 && summary.feedingMinutesTotal == 0) {
        try {
          summary = await AppDatabase.instance.dailySummaryForCalendarDay(babyId: id, calendarDay: day);
        } catch (_) {}
      }
      setState(() {
        _lastBreastOrBottleEndedAt = lastFeed;
        _lastDiaperChangedAt = results[1] as DateTime?;
        _lastSleepEndedAt = lastSleep;
        _dbDailySummary = summary;
        _summaryHintFeedEnd = hintFeedEnd;
        _summaryHintDiaperAt = results[5] as DateTime?;
        _summaryHintSleepEnd = results[6] as DateTime?;
        _dayVaccines = vRows.map(VaccineRecord.fromRow).toList();
        _dayVaccinesDue = vDueRows.map(VaccineRecord.fromRow).toList();
        _dayConsultations = cRows.map(ConsultationRecord.fromRow).toList();
        _bannerNextConsultation = upcomingRow == null ? null : ConsultationRecord.fromRow(upcomingRow);
      });
      await AppDatabase.instance.ensureYesterdayDailySummarySnapshot(babyId: id);
    } catch (e, st) {
      // Não "zera" o resumo por falha transitória (corridas de BD / rede / hydration).
      // Mantemos o último estado válido e só registramos para diagnóstico.
      debugPrint('HomePage._refreshRealtimeHomeMetricsFromDb failed: $e\n$st');
    }
  }

  Future<void> _pickSummaryDay() async {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final birth = _liveBabyBirthDate ?? today.subtract(const Duration(days: 365));
    var first = DateTime(birth.year, birth.month, birth.day);
    final oldest = today.subtract(const Duration(days: 365 * 4));
    if (first.isAfter(today)) first = oldest;
    if (first.isBefore(oldest)) first = oldest;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay.isAfter(today) ? today : _selectedDay,
      firstDate: first,
      lastDate: today,
      helpText: S.of(context).homeSummaryPickDayTooltip,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDay = _dateOnly(picked));
    await _refreshRealtimeHomeMetricsFromDb();
  }

  @override
  void dispose() {
    CurrentBabyController.instance.removeListener(_onCurrentBabyUiChanged);
    CurrentBabyController.instance.removeListener(_onHomeFeedSourcesChanged);
    FeedingEvents.revision.removeListener(_onHomeFeedSourcesChanged);
    DiaperEvents.revision.removeListener(_onHomeFeedSourcesChanged);
    SleepEvents.revision.removeListener(_onHomeFeedSourcesChanged);
    GrowthEvents.revision.removeListener(_onHomeFeedSourcesChanged);
    HealthCalendarEvents.revision.removeListener(_onHomeFeedSourcesChanged);
    HomePrefs.feedingAlertsEnabled.removeListener(_onFeedingIntervalPrefsChanged);
    HomePrefs.feedingAlertIntervalMinutes.removeListener(_onFeedingIntervalPrefsChanged);
    HomePrefs.sleepAlertsEnabled.removeListener(_onFeedingIntervalPrefsChanged);
    MeasurementUnitsPrefs.weight.removeListener(_onHomeUnitsChanged);
    MeasurementUnitsPrefs.length.removeListener(_onHomeUnitsChanged);
    MeasurementUnitsPrefs.liquid.removeListener(_onHomeUnitsChanged);
    MeasurementUnitsPrefs.temperature.removeListener(_onHomeUnitsChanged);
    super.dispose();
  }

  void _onHomeUnitsChanged() {
    _refreshRealtimeHomeMetricsFromDb();
    if (mounted) setState(() {});
  }

  String _fmtHm(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _fmtCalendarDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  bool get _isTodayView => _dateOnly(_selectedDay) == _dateOnly(DateTime.now());

  DailySummary get _summary =>
      _dbDailySummary ??
      const DailySummary(
        feedings: 0,
        feedingMinutesTotal: 0,
        sleep: '0m',
        sleepSessions: 0,
        diapers: 0,
        diaperPee: 0,
        diaperPoo: 0,
        weight: '—',
        sleepTotalSeconds: 0,
      );

  HomeDaySnapshot get _pastSnapshot => widget.babyService.snapshotForDay(_selectedDay);

  Future<void> _openPhotoPreview({
    required S s,
    required String title,
    required Widget avatar,
    required VoidCallback? onChange,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppTheme.pageHPadding, 10, AppTheme.pageHPadding, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                Center(child: avatar),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onChange == null
                        ? null
                        : () {
                            Navigator.of(ctx).pop();
                            onChange();
                          },
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(s.changePhoto),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final motherRaw = (widget.motherName ?? '').trim();
    final greeting = motherRaw.isEmpty ? s.helloMom : s.helloMomNamed(motherRaw);
    late final DateTime? primaryLastFeedAt;
    late final DateTime? bannerLastDiaperAt;
    late final DateTime? bannerSleepEndedAtDisplay;
    late final String lastFeedHint;
    late final String lastDiaperHint;
    late final String lastSleepHint;
    if (_isTodayView) {
      primaryLastFeedAt = _lastBreastOrBottleEndedAt;
      bannerLastDiaperAt = _lastDiaperChangedAt;
      bannerSleepEndedAtDisplay = _lastSleepEndedAt;
    } else {
      final snap = _pastSnapshot;
      primaryLastFeedAt = snap.lastFeedingAt;
      bannerLastDiaperAt = snap.lastPeeAt.isAfter(snap.lastPooAt) ? snap.lastPeeAt : snap.lastPooAt;
      bannerSleepEndedAtDisplay = snap.lastSleepAt;
    }
    lastFeedHint = switch (_summaryHintFeedEnd) {
      null => s.feedingNoRecords,
      final d => s.summaryLastFeed(_fmtHm(d)),
    };
    final summaryDiaper = _summaryHintDiaperAt;
    lastDiaperHint = summaryDiaper == null ? s.diaperHistoryEmpty : s.summaryLastFeed(_fmtHm(summaryDiaper));
    final summarySleep = _summaryHintSleepEnd;
    lastSleepHint = summarySleep == null ? s.summarySleepNotYet : s.summaryLastSleep(_fmtHm(summarySleep));
    final weightCompact = _summary.weight.replaceAll(' ', '');
    final weightHint =
        weightCompact.contains('—') ? s.summaryWeightNotYet : s.homeSummaryExtraHint;

    final backdropTint = AppTheme.backdropTintForSex(widget.baby.sex);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(AppTheme.background, backdropTint, 0.14)!,
      ),
      child: RefreshIndicator(
        onRefresh: _onPullRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: EdgeInsets.fromLTRB(AppTheme.pageHPadding, 18, AppTheme.pageHPadding, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        Colors.white,
                        widget.baby.sex == 'M' ? AppTheme.babyBlue : AppTheme.primaryPurple,
                        0.05,
                      )!,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: (widget.baby.sex == 'M' ? AppTheme.babyBlue : AppTheme.primaryPurple).withAlpha(52),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPurple.withAlpha(22),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: (widget.baby.sex == 'M' ? AppTheme.babyBlue : AppTheme.mint).withAlpha(18),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Image.asset('assets/logo.png', height: 52, fit: BoxFit.contain),
                              ],
                            ),
                          ),
                        ),
                        if (widget.onPickBaby != null)
                          IconButton(
                            tooltip: s.changeBabyTooltip,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            onPressed: widget.onPickBaby,
                            iconSize: 22,
                            icon: CircleAvatar(
                              radius: 16,
                              backgroundColor: AppTheme.babyBlue.withAlpha(44),
                              child: const Icon(Icons.child_care_outlined, color: AppTheme.babyBlue, size: 22),
                            ),
                          ),
                        Theme(
                          data: Theme.of(context).copyWith(
                            iconButtonTheme: IconButtonThemeData(
                              style: IconButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(40, 40),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                          child: const LanguageButton(),
                        ),
                        IconButton(
                          tooltip: s.notificationsInboxTitle,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          iconSize: 22,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const NotificationsInboxPage(),
                              ),
                            );
                          },
                          icon: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.mint.withAlpha(50),
                            child: const Icon(Icons.notifications_none, size: 21, color: AppTheme.secondary),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _openPhotoPreview(
                              s: s,
                              title: s.motherPhotoTitle,
                              avatar: PhotoAvatar(
                                photoB64: _liveMotherPhotoB64,
                                photoUrl: _liveMotherPhotoUrl,
                                radius: 70,
                                backgroundColor: AppTheme.softPink,
                                fallback: const Icon(Icons.person, color: AppTheme.secondary, size: 48),
                              ),
                              onChange: widget.onPickMotherPhoto,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: PhotoAvatar(
                                photoB64: _liveMotherPhotoB64,
                                photoUrl: _liveMotherPhotoUrl,
                                radius: 18,
                                backgroundColor: AppTheme.softPink,
                                fallback: const Icon(Icons.person, color: AppTheme.secondary, size: 18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, greetC) {
                      final narrow = greetC.maxWidth < 360;
                      final consult = _consultationForBanner;
                      final tip = _HomeDailyTipLoader(
                        birthDate: _liveBabyBirthDate,
                        babyId: CurrentBabyController.instance.currentBabyId,
                        title: s.homeTipTitle,
                        fallbackBody: s.homeTipBody(_liveBabyName),
                        lang: s.lang,
                      );
                      final consultAlert = consult == null
                          ? null
                          : _HomeConsultationInlineAlert(
                              title: consult.title,
                              when: consult.occurredAt,
                              onTap: () => showConsultationDetailSheet(context, consult),
                            );
                      final greetBlock = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              style: TextStyle(
                                fontSize: portalSp(context, 22),
                                fontWeight: FontWeight.w900,
                                height: 1.25,
                                color: AppTheme.textPrimary,
                              ),
                              children: [
                                TextSpan(text: greeting),
                                TextSpan(
                                  text: ' 💜',
                                  style: TextStyle(
                                    fontSize: portalSp(context, 22),
                                    color: AppTheme.primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 3,
                            softWrap: true,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.homeGreetingSubtitle,
                            style: TextStyle(
                              fontSize: portalSp(context, 14),
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              color: AppTheme.textSecondary.withAlpha(230),
                            ),
                          ),
                        ],
                      );
                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            greetBlock,
                            const SizedBox(height: 12),
                            if (consultAlert != null) ...[
                              consultAlert,
                              const SizedBox(height: 10),
                            ],
                            tip,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 58, child: greetBlock),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 42,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (consultAlert != null) ...[
                                  consultAlert,
                                  const SizedBox(height: 10),
                                ],
                                tip,
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _PrimaryBabyCard(
                    baby: widget.baby,
                    routineBirthDate: _liveBabyBirthDate,
                    babyId: CurrentBabyController.instance.currentBabyId,
                    isTodayView: _isTodayView,
                    lastFeedingAt: primaryLastFeedAt,
                    lastDiaperChangedAt: bannerLastDiaperAt,
                    lastSleepEndedAt: _lastSleepEndedAt,
                    sleepBannerEndedAtDisplay: bannerSleepEndedAtDisplay,
                    bannerDiaperAlert: _isTodayView &&
                        _lastDiaperChangedAt != null &&
                        DateTime.now().difference(_lastDiaperChangedAt!).inMinutes >= _kHomeBannerDiaperOverdueMin,
                    bannerConsultation: _consultationForBanner,
                    bannerVaccinesDueToday: _dayVaccinesDue,
                    onBannerConsultationTap: () {
                      final c = _consultationForBanner;
                      if (c != null) showConsultationDetailSheet(context, c);
                    },
                    feedingIntervalMinutes: HomePrefs.feedingAlertIntervalMinutes.value,
                    onTapOpenDiaperBanner: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DiaperPage())),
                    onTapOpenSleepBanner: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SleepPage())),
                    onTapFeedNow: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => FeedingHubPage(appBarTitle: s.shortcutMilk),
                        )),
                    onOpenBabyPhoto: widget.onPickBabyPhoto == null
                        ? null
                        : () => _openPhotoPreview(
                              s: s,
                              title: s.babyPhotoTitle,
                              avatar: PhotoAvatar(
                                photoB64: _liveBabyPhotoB64,
                                photoUrl: _liveBabyPhotoUrl,
                                radius: 76,
                                backgroundColor: widget.baby.sex == 'M' ? const Color(0xFFD6EBFF) : const Color(0xFFFFDCE8),
                                fallback: Text(widget.baby.avatar, style: const TextStyle(fontSize: 62)),
                              ),
                              onChange: widget.onPickBabyPhoto,
                            ),
                    onPickBabyPhoto: widget.onPickBabyPhoto,
                    babyAvatarPhotoB64: _liveBabyPhotoB64,
                    babyAvatarPhotoUrl: _liveBabyPhotoUrl,
                  ),
                  _DevelopmentLeapHomeCard(
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DevelopmentLeapsPage()),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SectionTitle(
                    title: s.shortcuts,
                    action: TextButton(onPressed: widget.onOpenQuickRegister, child: Text(s.seeAll)),
                  ),
                  const SizedBox(height: 4),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      const count = 3;
                      const gap = 10.0;
                      final tileW = (w - (gap * (count - 1))) / count;
                      // Atalhos bem achatados na vertical (células mais baixas).
                      final idealH = w < 340
                          ? 112.0
                          : w < 400
                              ? 106.0
                              : 102.0;
                      final ratio = (tileW / idealH).clamp(0.62, 1.15);
                      return GridView.count(
                        crossAxisCount: count,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: gap,
                        mainAxisSpacing: gap,
                        childAspectRatio: ratio,
                        children: [
                          _ShortcutCard(
                            icon: Icons.local_drink,
                            title: s.shortcutMilk,
                            subtitle: s.shortcutMilkHomeSub,
                            color: AppTheme.primaryPink,
                            softBg: const Color(0xFFFFE8F0),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                                  builder: (_) => FeedingHubPage(appBarTitle: s.shortcutMilk),
                                )),
                          ),
                          _ShortcutCard(
                            icon: Icons.monitor_weight_outlined,
                            title: s.growth,
                            subtitle: s.shortcutGrowthHomeSub,
                            color: const Color(0xFF00C4CC),
                            softBg: const Color(0xFFE7FBFC),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                                  builder: (_) => GrowthDashboardPage(appBarTitle: s.growth),
                                )),
                          ),
                          _ShortcutCard(
                            icon: Icons.nightlight_round,
                            title: s.shortcutSleep,
                            subtitle: s.shortcutSleepHomeSub,
                            color: AppTheme.primary,
                            softBg: AppTheme.softPurple,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SleepPage())),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  SectionTitle(
                    title: _isTodayView ? s.todaySummary : s.homeSummaryOnDate(_fmtCalendarDate(_selectedDay)),
                    action: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isTodayView)
                          TextButton(
                            onPressed: () async {
                              setState(() => _selectedDay = _dateOnly(DateTime.now()));
                              await _refreshRealtimeHomeMetricsFromDb();
                            },
                            child: Text(s.homeTodayLabel),
                          ),
                        IconButton(
                          tooltip: s.homeSummaryPickDayTooltip,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          icon: Icon(Icons.calendar_month_rounded, size: 22, color: AppTheme.secondary.withAlpha(230)),
                          onPressed: _pickSummaryDay,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  LayoutBuilder(
                    builder: (context, gridC) {
                      const gap = 8.0;
                      final narrow = gridC.maxWidth < 336;
                      Widget summaryValueTwoLines({
                        required IconData topIcon,
                        required String topText,
                        required IconData bottomIcon,
                        required String bottomText,
                        required Color accent,
                      }) {
                        Widget line(IconData icon, String text, {required TextStyle style}) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: portalSp(context, 13).clamp(12.0, 14.0),
                                color: AppTheme.textMuted.withAlpha(210),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  text,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: style,
                                ),
                              ),
                            ],
                          );
                        }

                        final topStyle = TextStyle(
                          fontSize: portalSp(context, 15.5),
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          letterSpacing: -0.25,
                          color: AppTheme.textSecondary.withAlpha(240),
                        );
                        final bottomStyle = TextStyle(
                          fontSize: portalSp(context, 13.5),
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          letterSpacing: -0.15,
                          color: AppTheme.textMuted.withAlpha(230),
                        );

                        return ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: gridC.maxWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              line(topIcon, topText, style: topStyle),
                              const SizedBox(height: 2),
                              line(bottomIcon, bottomText, style: bottomStyle),
                            ],
                          ),
                        );
                      }

                      final summaryCards = <Widget>[
                        _TodaySummaryCard(
                          icon: Icons.local_drink,
                          color: AppTheme.primaryPink,
                          softBg: const Color(0xFFF4EFF2),
                          value: summaryValueTwoLines(
                            topIcon: Icons.numbers_rounded,
                            topText: s.summaryFeedingsCount(_summary.feedings),
                            bottomIcon: Icons.schedule_rounded,
                            bottomText: s.summaryFeedingsMinutes(_summary.feedingMinutesTotal),
                            accent: AppTheme.primaryPink,
                          ),
                          label: s.summaryFeedings,
                          hint: lastFeedHint,
                        ),
                        _TodaySummaryCard(
                          icon: Icons.baby_changing_station_rounded,
                          color: AppTheme.mint,
                          softBg: const Color(0xFFEEF8F6),
                          value: summaryValueTwoLines(
                            topIcon: Icons.layers_rounded,
                            topText: s.summaryDiapersChanges(_summary.diapers),
                            bottomIcon: Icons.water_drop_rounded,
                            bottomText: s.summaryDiapersPeePoo(_summary.diaperPee, _summary.diaperPoo),
                            accent: AppTheme.mint,
                          ),
                          label: s.summaryDiapers,
                          hint: lastDiaperHint,
                        ),
                        _TodaySummaryCard(
                          icon: Icons.nightlight_round,
                          color: AppTheme.primary,
                          softBg: const Color(0xFFF0F1F6),
                          value: summaryValueTwoLines(
                            topIcon: Icons.bedtime_rounded,
                            topText: s.summarySleepSessions(_summary.sleepSessions),
                            bottomIcon: Icons.timer_outlined,
                            bottomText: _summary.sleep.replaceAll(' ', ''),
                            accent: AppTheme.primary,
                          ),
                          label: s.summarySleep,
                          hint: lastSleepHint,
                        ),
                        _TodaySummaryCard(
                          icon: Icons.monitor_weight_outlined,
                          color: AppTheme.yellow,
                          softBg: const Color(0xFFF7F4EE),
                          value: Text(
                            _summary.weight.replaceAll(' ', ''),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                          label: s.summaryWeight,
                          hint: weightHint,
                        ),
                      ];
                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < summaryCards.length; i++) ...[
                              if (i > 0) const SizedBox(height: gap),
                              summaryCards[i],
                            ],
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: summaryCards[0]),
                              const SizedBox(width: gap),
                              Expanded(child: summaryCards[1]),
                            ],
                          ),
                          const SizedBox(height: gap),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: summaryCards[2]),
                              const SizedBox(width: gap),
                              Expanded(child: summaryCards[3]),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  _HomeDayHealthStrip(
                    s: s,
                    vaccines: _dayVaccines,
                    consultations: _dayConsultations,
                    fmtHm: _fmtHm,
                  ),
                  const SizedBox(height: 14),
                  _HomeMotivationBanner(
                    text: s.homeMotivationBanner,
                    linkLabel: s.homeMotivationBannerOpenMemories,
                    onOpenMemories: () {
                      ShellNestedNav.tabNavigatorKeys[2].currentState?.popUntil((route) => route.isFirst);
                      ShellNestedNav.selectTab?.call(2);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _HealthSortEntry {
  final DateTime at;
  final Widget child;

  _HealthSortEntry({required this.at, required this.child});
}

/// Vacinas e consultas registadas no mesmo dia civil que o resumo (abaixo dos 4 quadrados).
class _HomeDayHealthStrip extends StatelessWidget {
  final S s;
  final List<VaccineRecord> vaccines;
  final List<ConsultationRecord> consultations;
  final String Function(DateTime) fmtHm;

  const _HomeDayHealthStrip({
    required this.s,
    required this.vaccines,
    required this.consultations,
    required this.fmtHm,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <_HealthSortEntry>[];
    for (final v in vaccines) {
      final at = v.appliedAt;
      if (at == null) continue;
      entries.add(
        _HealthSortEntry(
          at: at,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const VaccinesPage(),
              ));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.vaccines_outlined, color: AppTheme.primaryPink, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        if (v.dose != null && v.dose!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              v.dose!,
                              style: TextStyle(fontSize: 13, color: Colors.black.withAlpha(140)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    fmtHm(at),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.secondary.withAlpha(220),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    for (final c in consultations) {
      entries.add(
        _HealthSortEntry(
          at: c.occurredAt,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showConsultationDetailSheet(context, c),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.medical_services_outlined, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        if (c.notes != null && c.notes!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              c.notes!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: Colors.black.withAlpha(140)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    fmtHm(c.occurredAt),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.secondary.withAlpha(220),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    entries.sort((a, b) => a.at.compareTo(b.at));

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.homeSummaryHealthStripTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Text(
              s.homeSummaryHealthStripEmpty,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black.withAlpha(140),
                height: 1.35,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: Colors.black.withAlpha(28)),
                  entries[i].child,
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _PrimaryBabyCard extends StatefulWidget {
  final Baby baby;
  /// Preferir data da BD; [Baby] do shell pode ficar stale no Navigator do tab.
  final DateTime? routineBirthDate;
  final int? babyId;
  final bool isTodayView;
  /// Hoje: último registro ao peito ou mamadeira ou `null` se não houver. Dia passado: sempre preenchido (mock).
  final DateTime? lastFeedingAt;
  /// `null` no dia de hoje se ainda não houver trocas na BD (mostra texto vazio seguro).
  final DateTime? lastDiaperChangedAt;
  /// Fim do último sono gravado (para janela «hora de dormir»).
  final DateTime? lastSleepEndedAt;
  /// Referência para o azulejo de sono na faixa (hoje: igual à BD; outro dia: snapshot).
  final DateTime? sleepBannerEndedAtDisplay;
  final bool bannerDiaperAlert;
  /// Próxima consulta futura (resumo no banner).
  final ConsultationRecord? bannerConsultation;
  final VoidCallback? onBannerConsultationTap;
  /// Vacinas com próxima dose **hoje** (mostradas como chip acima do banner).
  final List<VaccineRecord> bannerVaccinesDueToday;
  /// Intervalo configurado em Registros rápidos (min), para cores/ETA iguais ao alerta.
  final int feedingIntervalMinutes;
  final VoidCallback? onOpenBabyPhoto;
  final VoidCallback? onPickBabyPhoto;
  /// Preferir valor da BD; [Baby] no widget pai pode estar stale (Navigator do tab).
  final String? babyAvatarPhotoB64;
  final String? babyAvatarPhotoUrl;
  final VoidCallback? onTapFeedNow;
  final VoidCallback? onTapOpenDiaperBanner;
  final VoidCallback? onTapOpenSleepBanner;

  const _PrimaryBabyCard({
    required this.baby,
    this.routineBirthDate,
    required this.babyId,
    required this.isTodayView,
    required this.lastFeedingAt,
    required this.lastDiaperChangedAt,
    required this.lastSleepEndedAt,
    required this.sleepBannerEndedAtDisplay,
    required this.bannerDiaperAlert,
    this.bannerConsultation,
    this.onBannerConsultationTap,
    this.bannerVaccinesDueToday = const <VaccineRecord>[],
    required this.feedingIntervalMinutes,
    this.onOpenBabyPhoto,
    this.onPickBabyPhoto,
    this.babyAvatarPhotoB64,
    this.babyAvatarPhotoUrl,
    this.onTapFeedNow,
    this.onTapOpenDiaperBanner,
    this.onTapOpenSleepBanner,
  });

  @override
  State<_PrimaryBabyCard> createState() => _PrimaryBabyCardState();
}

class _PrimaryBabyCardState extends State<_PrimaryBabyCard> {
  Timer? _bannerSleepProgressTicker;

  DateTime? get _routineBirth => widget.routineBirthDate ?? widget.baby.birthDate;

  @override
  void initState() {
    super.initState();
    SleepTimerController.instance.addListener(_onSleepTimerTick);
    HomePrefs.sleepAlertsEnabled.addListener(_onSleepPrefs);
    _syncBannerSleepProgressTicker();
  }

  @override
  void didUpdateWidget(covariant _PrimaryBabyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTodayView != widget.isTodayView || oldWidget.babyId != widget.babyId) {
      _syncBannerSleepProgressTicker();
    }
  }

  void _syncBannerSleepProgressTicker() {
    final want = widget.isTodayView && widget.babyId != null;
    if (want && _bannerSleepProgressTicker == null) {
      // Atualização frequente para a barra de vigília avançar entre minutos inteiros (minutos fracionários).
      _bannerSleepProgressTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!want && _bannerSleepProgressTicker != null) {
      _bannerSleepProgressTicker!.cancel();
      _bannerSleepProgressTicker = null;
    }
  }

  @override
  void dispose() {
    _bannerSleepProgressTicker?.cancel();
    SleepTimerController.instance.removeListener(_onSleepTimerTick);
    HomePrefs.sleepAlertsEnabled.removeListener(_onSleepPrefs);
    super.dispose();
  }

  void _onSleepTimerTick() {
    if (mounted && widget.isTodayView) setState(() {});
  }

  void _onSleepPrefs() {
    if (mounted && widget.isTodayView) setState(() {});
  }

  int _sleepSessionCapMinutes() {
    final w = SleepRoutine.windowForMonths(SleepRoutine.monthsOld(_routineBirth));
    return math.max(180, w.maxAwakeMin * 2);
  }

  int _effectiveFeedingIntervalMinutes() {
    return widget.feedingIntervalMinutes < 20 ? 20 : widget.feedingIntervalMinutes;
  }

  /// Tempo até ao fim do intervalo de alimentação (negativo = atraso).
  Duration? _feedingCountdownRemaining() {
    if (!widget.isTodayView || widget.babyId == null) return null;
    final ended = widget.lastFeedingAt;
    if (ended == null) return null;
    final total = Duration(minutes: _effectiveFeedingIntervalMinutes());
    return total - DateTime.now().difference(ended);
  }

  /// Contagem decrescente: até acabar a janela acordado recomendada, ou até ao limite da sessão de sono.
  Duration? _sleepCountdownRemaining() {
    final t = SleepTimerController.instance;
    if (t.isTracking && t.babyId == widget.babyId) {
      final cap = Duration(minutes: _sleepSessionCapMinutes());
      return cap - t.effectiveElapsed;
    }
    final ended = widget.lastSleepEndedAt;
    if (ended == null) return null;
    final w = SleepRoutine.windowForMonths(SleepRoutine.monthsOld(_routineBirth));
    final budget = Duration(minutes: w.maxAwakeMin);
    return budget - DateTime.now().difference(ended);
  }

  // _bannerMidSection removido: o banner do bebê foi remodelado conforme referência.

  String _fmtHm(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _fmtElapsedShort(Duration d) {
    final mins = d.inMinutes;
    if (mins < 60) return '$mins\u00A0min';
    final h = d.inHours;
    final m = mins % 60;
    return '${h}h\u00A0${m.toString().padLeft(2, '0')}';
  }

  String _sleepBannerTileLabel(S s) {
    final timer = SleepTimerController.instance;
    if (widget.isTodayView &&
        widget.babyId != null &&
        timer.isTracking &&
        timer.babyId == widget.babyId) {
      final elapsed = timer.effectiveElapsed;
      final elapsedStr = _fmtElapsedShort(elapsed);
      if (timer.isPaused) {
        return s.homeSleepPausedBanner(elapsedStr);
      }
      return s.homeSleepInProgress(elapsedStr);
    }
    final ref = widget.sleepBannerEndedAtDisplay;
    if (ref == null) {
      return s.sleepBannerEmpty;
    }
    if (widget.isTodayView) {
      return s.homeSleepEndedAgo(_fmtAgo(ref));
    }
    return s.homeSleepEndedAt(_fmtHm(ref));
  }

  String _fmtAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}\u00A0min';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h\u00A0${m.toString().padLeft(2, '0')}';
  }

  String _fmtDurLong(Duration d) {
    final mins = d.inMinutes;
    if (mins <= 0) return '0 min';
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m.toString().padLeft(2, '0')} min';
  }

  String _fmtDurCompact(Duration d) {
    final mins = d.inMinutes;
    if (mins <= 0) return '0m';
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  String _fmtAgoNoMin(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  String _fmtClockRangeFrom(DateTime base, int minMinutes, int maxMinutes) {
    final a = base.add(Duration(minutes: minMinutes));
    final b = base.add(Duration(minutes: maxMinutes));
    return '${_fmtHm(a)} – ${_fmtHm(b)}';
  }

  String _feedingTileSubtitle(S s) {
    if (!widget.isTodayView) {
      return s.homeFedAt(_fmtHm(widget.lastFeedingAt!));
    }
    if (widget.lastFeedingAt == null) return s.feedingNoRecords;
    return s.homeFedAgo(_fmtAgo(widget.lastFeedingAt!));
  }

  String _diaperTileSubtitle(S s) {
    return switch ((widget.isTodayView, widget.lastDiaperChangedAt)) {
      (true, null) => s.diaperHistoryEmpty,
      (false, null) => s.diaperHistoryEmpty,
      (false, final DateTime d) => s.homeDiaperChangeAt(_fmtHm(d)),
      (true, final DateTime d) => s.homeDiaperChangeAgo(_fmtAgo(d)),
    };
  }

  /// Peso, altura e idade numa linha, separados por · (mesmo estilo tipográfico).
  String _babyBannerStatsLine() {
    final age = widget.baby.ageLabel.trim();
    final wStr = MeasurementFormat.weight(widget.baby.weightKg, decimalsKg: 2);
    final hStr = MeasurementFormat.length(widget.baby.heightCm, decimalsCm: 0);
    return '$wStr · $hStr · $age';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bg = widget.baby.sex == 'M' ? const Color(0xFFD6EBFF) : const Color(0xFFE8ECF2);
    final interval = widget.feedingIntervalMinutes < 20 ? 20 : widget.feedingIntervalMinutes;
    final timeToFeedNow = widget.isTodayView &&
        widget.lastFeedingAt != null &&
        DateTime.now().difference(widget.lastFeedingAt!).inMinutes >= interval;

    final nameColor = (widget.baby.sex == 'M') ? AppTheme.babyBlue : AppTheme.primaryPurple;
    final accent = widget.baby.sex == 'M' ? AppTheme.babyBlue : AppTheme.ctaPrimary;
    final babyNameStyle = TextStyle(
      fontSize: portalSp(context, 22),
      fontWeight: FontWeight.w900,
      color: nameColor,
      height: 1.08,
      letterSpacing: -0.38,
    );
    /// Diâmetro da foto + anel (padding 2.5 px).
    const avatarOuter = 42 * 2 + 5;

    return LayoutBuilder(
      builder: (context, cardConstraints) {
        final narrow = cardConstraints.maxWidth < 340;
        final tileGap = narrow ? 4.0 : 6.0;
        final hPad = narrow ? 10.0 : 12.0;

        List<Widget> _bannerAlertChips() {
          if (!widget.isTodayView) return const <Widget>[];
          final sleepRem = _sleepCountdownRemaining();
          final sleepOverdue = sleepRem != null && sleepRem.isNegative;
          final feedRem = _feedingCountdownRemaining();
          final feedOverdue = feedRem != null && feedRem.isNegative;

          const criticalRed = Color(0xFFD63535);
          final criticalBg = Color.lerp(Colors.white, criticalRed, 0.10)!;

          Widget chip({
            required IconData icon,
            required Color color,
            required String label,
            VoidCallback? onTap,
          }) {
            return Material(
              color: Color.lerp(Colors.white, color, 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: color.withAlpha(70)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: color.withAlpha(240)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: portalSp(context, 10.5),
                            color: AppTheme.textPrimary,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          Widget criticalChip({
            required IconData icon,
            required String label,
            VoidCallback? onTap,
          }) {
            return Material(
              color: criticalBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: criticalRed.withAlpha(80)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: criticalRed.withAlpha(245)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: portalSp(context, 10.5),
                            color: criticalRed.withAlpha(245),
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          Future<void> openCriticalList(List<_CriticalBannerAlert> alerts) async {
            if (alerts.isEmpty) return;
            await showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              showDragHandle: true,
              builder: (ctx) {
                final ss = S.of(ctx);
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          ss.homeCriticalCareTitle,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        for (final a in alerts)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: Color.lerp(Colors.white, criticalRed, 0.10),
                              child: Icon(a.icon, color: criticalRed),
                            ),
                            title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(a.subtitle),
                            ),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              a.onTap?.call();
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          }

          final critical = <_CriticalBannerAlert>[];
          if (timeToFeedNow || feedOverdue) {
            critical.add(_CriticalBannerAlert(
              kind: _CriticalBannerAlertKind.feeding,
              icon: Icons.local_drink_rounded,
              title: s.homeCriticalFeedingTitle,
              subtitle: s.homeCriticalFeedingSubtitle,
              onTap: widget.onTapFeedNow,
            ));
          }
          if (sleepOverdue) {
            critical.add(_CriticalBannerAlert(
              kind: _CriticalBannerAlertKind.sleep,
              icon: Icons.nights_stay_rounded,
              title: s.homeCriticalSleepTitle,
              subtitle: s.homeCriticalSleepSubtitle,
              onTap: widget.onTapOpenSleepBanner,
            ));
          }
          if (widget.bannerDiaperAlert) {
            critical.add(_CriticalBannerAlert(
              kind: _CriticalBannerAlertKind.diaper,
              icon: Icons.baby_changing_station_rounded,
              title: s.homeCriticalDiaperTitle,
              subtitle: s.homeCriticalDiaperSubtitle,
              onTap: widget.onTapOpenDiaperBanner,
            ));
          }

          // Prioridade visual: mamada > sono > fralda.
          critical.sort((a, b) => a.kind.priority.compareTo(b.kind.priority));

          final items = <Widget>[
            if (widget.bannerVaccinesDueToday.isNotEmpty)
              chip(
                icon: Icons.vaccines_outlined,
                color: AppTheme.primaryPink,
                label: s.homeBannerChipVaccine,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VaccinesPage())),
              ),
            if (critical.length >= 2)
              criticalChip(
                icon: Icons.error_rounded,
                label: s.homeCriticalCareCount(critical.length),
                onTap: () => openCriticalList(critical),
              )
            else if (critical.length == 1)
              criticalChip(
                icon: critical.first.icon,
                label: critical.first.title,
                onTap: () => openCriticalList(critical),
              ),
          ];
          return items;
        }

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE8EAEF)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: accent.withAlpha(18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: avatarOuter.toDouble(),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent,
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withAlpha(55),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(2.5),
                            child: GestureDetector(
                              onTap: widget.onOpenBabyPhoto,
                              child: PhotoAvatar(
                                photoB64: widget.babyAvatarPhotoB64 ?? widget.baby.photoB64,
                                photoUrl: widget.babyAvatarPhotoUrl ?? widget.baby.photoUrl,
                                radius: 42,
                                backgroundColor: bg,
                                fallback: Text(widget.baby.avatar, style: const TextStyle(fontSize: 36)),
                              ),
                            ),
                          ),
                          Positioned(
                            right: -1,
                            bottom: -1,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(22),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.favorite_rounded, size: 13, color: accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: narrow ? 8 : 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.baby.name,
                                  maxLines: 2,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  style: babyNameStyle,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: narrow ? 5 : 6),
                          Text(
                            _babyBannerStatsLine(),
                            style: TextStyle(
                              fontSize: portalSp(context, narrow ? 12.5 : 13),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF454658),
                              height: 1.25,
                              letterSpacing: -0.12,
                            ),
                          ),
                          if (widget.isTodayView) ...[
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                final items = _bannerAlertChips();
                                if (items.isEmpty) {
                                  final g = AppTheme.green;
                                  return Material(
                                    color: Color.lerp(Colors.white, g, 0.14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(color: g.withAlpha(70)),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_circle_rounded, size: 18, color: g.withAlpha(235)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              s.homeStatusOk,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: portalSp(context, 11),
                                                color: AppTheme.textPrimary,
                                                height: 1.2,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                return Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: items,
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Novos quadros: começam abaixo da foto e ocupam a largura toda.
                if (widget.isTodayView) ...[
                  SizedBox(height: narrow ? 10 : 12),
                  _BabyBannerForecastCard(
                    sleeping: SleepTimerController.instance.isTracking &&
                        SleepTimerController.instance.babyId == widget.babyId,
                    title: (SleepTimerController.instance.isTracking &&
                            SleepTimerController.instance.babyId == widget.babyId)
                        ? s.homeBabyBannerForecastWake
                        : s.homeBabyBannerForecastSleep,
                    subtitle: (SleepTimerController.instance.isTracking &&
                            SleepTimerController.instance.babyId == widget.babyId)
                        ? s.homeBabyBannerForecastSubtitleWake
                        : s.homeBabyBannerForecastSubtitleSleep,
                    etaLabel: () {
                      final t = SleepTimerController.instance;
                      final sleeping = t.isTracking && t.babyId == widget.babyId;
                      if (sleeping) {
                        final rem = _sleepCountdownRemaining();
                        final startedAt = t.startedAt;
                        if (rem != null && rem.isNegative && startedAt != null) {
                          return s.homeBannerOverdueWake;
                        }
                        return s.homeBabyBannerEtaIn(
                          _fmtDurLong((rem ?? Duration.zero).isNegative ? Duration.zero : (rem ?? Duration.zero)),
                        );
                      }
                      final ended = widget.lastSleepEndedAt;
                      if (ended == null) return '—';
                      final w = SleepRoutine.windowForMonths(SleepRoutine.monthsOld(_routineBirth));
                      final budgetTarget = ended.add(Duration(minutes: w.maxAwakeMin));
                      if (DateTime.now().isAfter(budgetTarget)) {
                        return s.homeBannerOverdueSleep;
                      }
                      final awakeMinutes = DateTime.now().difference(ended).inMinutes;
                      final m = SleepRoutine.estimateNextNapMinutes(awakeMinutes: awakeMinutes, w: w);
                      return s.homeBabyBannerEtaIn(_fmtDurLong(Duration(minutes: m)));
                    }(),
                    exhausted: () {
                      final rem = _sleepCountdownRemaining();
                      if (rem == null) return false;
                      return rem.isNegative;
                    }(),
                    percent: () {
                      final t = SleepTimerController.instance;
                      final sleeping = t.isTracking && t.babyId == widget.babyId;
                      if (sleeping) {
                        final cap = _sleepSessionCapMinutes();
                        if (cap <= 0) return 0;
                        final p = (t.effectiveElapsed.inMinutes / cap).clamp(0.0, 1.0);
                        return (p * 100).round();
                      }
                      final ended = widget.lastSleepEndedAt;
                      if (ended == null) return 0;
                      final w = SleepRoutine.windowForMonths(SleepRoutine.monthsOld(_routineBirth));
                      final awake = DateTime.now().difference(ended).inMinutes;
                      final p = ((awake.toDouble()) / w.maxAwakeMin).clamp(0.0, 1.0);
                      return (p * 100).round();
                    }(),
                    progress01: () {
                      final t = SleepTimerController.instance;
                      final sleeping = t.isTracking && t.babyId == widget.babyId;
                      if (sleeping) {
                        final cap = _sleepSessionCapMinutes();
                        if (cap <= 0) return 0.0;
                        return ((t.effectiveElapsed.inMinutes.toDouble()) / cap).clamp(0.0, 1.0);
                      }
                      final ended = widget.lastSleepEndedAt;
                      if (ended == null) return 0.0;
                      final w = SleepRoutine.windowForMonths(SleepRoutine.monthsOld(_routineBirth));
                      final awake = DateTime.now().difference(ended).inMinutes;
                      return ((awake.toDouble()) / w.maxAwakeMin).clamp(0.0, 1.0);
                    }(),
                    windowLabel: () {
                      final w = SleepRoutine.windowForMonths(SleepRoutine.monthsOld(_routineBirth));
                      final ended = widget.lastSleepEndedAt;
                      if (ended == null) return s.homeBabyBannerIdealWindow('—');
                      return s.homeBabyBannerIdealWindow(
                        _fmtClockRangeFrom(ended, w.minAwakeMin, w.maxAwakeMin),
                      );
                    }(),
                    onTap: widget.onTapOpenSleepBanner,
                  ),
                  SizedBox(height: narrow ? 10 : 12),
                  LayoutBuilder(
                    builder: (context, c) {
                      final isNarrow = c.maxWidth < 360;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _BabyBannerTimelineCard(
                              icon: Icons.local_drink_rounded,
                              accent: const Color(0xFFFF5A6E),
                              softBg: const Color(0xFFFFF0F2),
                              title: s.feedingLast,
                              value: () {
                                final ended = widget.lastFeedingAt;
                                if (ended == null) return '—';
                                final limit = Duration(minutes: interval);
                                final elapsed = DateTime.now().difference(ended);
                                if (elapsed >= limit) return s.homeBannerHungry;
                                return 'há ${_fmtAgo(ended)}';
                              }(),
                              subtitle: widget.lastFeedingAt == null
                                  ? s.homeBabyBannerNoRecordsYet
                                  : () {
                                      final minEta = math.max(0, interval - 30);
                                      final maxEta = interval;
                                      return s.homeBabyBannerNextBetween(
                                        _fmtClockRangeFrom(widget.lastFeedingAt!, minEta, maxEta),
                                      );
                                    }(),
                              progress01: () {
                                if (widget.lastFeedingAt == null) return 0.0;
                                final elapsed = DateTime.now().difference(widget.lastFeedingAt!).inMinutes;
                                return (elapsed / interval).clamp(0.0, 1.0);
                              }(),
                              maxLabel: '${(interval / 60).floor()}h',
                              exhausted: widget.lastFeedingAt != null &&
                                  DateTime.now().difference(widget.lastFeedingAt!).inMinutes >= interval,
                              onTap: widget.onTapFeedNow,
                              dense: isNarrow,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _BabyBannerTimelineCard(
                              icon: Icons.baby_changing_station_rounded,
                              accent: const Color(0xFF00BFA6),
                              softBg: const Color(0xFFEFFAF7),
                              title: s.homeBabyBannerLastDiaper,
                              value: () {
                                final changedAt = widget.lastDiaperChangedAt;
                                if (changedAt == null) return '—';
                                const maxMin = 210;
                                final limit = const Duration(minutes: maxMin);
                                final elapsed = DateTime.now().difference(changedAt);
                                if (elapsed >= limit) return s.homeBannerDiaperDirty;
                                return 'há ${_fmtAgoNoMin(changedAt)}';
                              }(),
                              subtitle: widget.lastDiaperChangedAt == null
                                  ? s.homeBabyBannerNoRecordsYet
                                  : () {
                                      const maxMin = 210;
                                      final elapsed = DateTime.now().difference(widget.lastDiaperChangedAt!).inMinutes;
                                      final rem = (maxMin - elapsed).clamp(0, maxMin);
                                      // 210 min = 3h30. Mostramos o tempo restante compacto (ex.: 3h18).
                                      return s.homeBabyBannerDiaperRecommendedUntil(
                                        _fmtDurCompact(Duration(minutes: rem)),
                                      );
                                    }(),
                              progress01: () {
                                if (widget.lastDiaperChangedAt == null) return 0.0;
                                const maxMin = 210;
                                final elapsed = DateTime.now().difference(widget.lastDiaperChangedAt!).inMinutes;
                                return (elapsed / maxMin).clamp(0.0, 1.0);
                              }(),
                              maxLabel: '3h30',
                              exhausted: widget.lastDiaperChangedAt != null &&
                                  DateTime.now().difference(widget.lastDiaperChangedAt!).inMinutes >= 210,
                              onTap: widget.onTapOpenDiaperBanner,
                              dense: isNarrow,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                if (!widget.isTodayView) ...[
                  SizedBox(height: narrow ? 10 : 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _BabyQuickTile(
                          narrow: narrow,
                          icon: Icons.local_drink_rounded,
                          title: s.shortcutMilk,
                          subtitle: _feedingTileSubtitle(s),
                          iconColor: AppTheme.yellow,
                          tileBackground: const Color(0xFFFFF9ED),
                          onTap: timeToFeedNow ? widget.onTapFeedNow : null,
                        ),
                      ),
                      SizedBox(width: tileGap),
                      Expanded(
                        child: _BabyQuickTile(
                          narrow: narrow,
                          icon: Icons.baby_changing_station_rounded,
                          title: s.homeTileDiapers,
                          subtitle: _diaperTileSubtitle(s),
                          iconColor: AppTheme.babyBlue,
                          tileBackground: const Color(0xFFEEF6FF),
                          onTap: widget.onTapOpenDiaperBanner,
                        ),
                      ),
                      SizedBox(width: tileGap),
                      Expanded(
                        child: _BabyQuickTile(
                          narrow: narrow,
                          icon: Icons.nightlight_round,
                          title: s.shortcutSleep,
                          subtitle: _sleepBannerTileLabel(s),
                          iconColor: AppTheme.primaryPurple,
                          tileBackground: const Color(0xFFF4F0FC),
                          onTap: widget.onTapOpenSleepBanner,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BabyBannerForecastCard extends StatelessWidget {
  final bool sleeping;
  final String title;
  final String subtitle;
  final String etaLabel;
  final int percent;
  final double progress01;
  final String windowLabel;
  final bool exhausted;
  final VoidCallback? onTap;

  const _BabyBannerForecastCard({
    required this.sleeping,
    required this.title,
    required this.subtitle,
    required this.etaLabel,
    required this.percent,
    required this.progress01,
    required this.windowLabel,
    this.exhausted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = sleeping ? const Color(0xFFFFB020) : const Color(0xFF7A5CF6);
    final icon = sleeping ? Icons.wb_sunny_rounded : Icons.nightlight_round;
    final art = sleeping ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded;

    Widget rightMetrics() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exhausted ? S.of(context).homeBannerExhausted : '$percent%',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: portalSp(context, 14),
              color: AppTheme.primaryPurple,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress01.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.black.withAlpha(18),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple.withAlpha(230)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0%', style: TextStyle(fontSize: 10.5, color: Colors.black.withAlpha(125), fontWeight: FontWeight.w800)),
              Text('50%', style: TextStyle(fontSize: 10.5, color: Colors.black.withAlpha(125), fontWeight: FontWeight.w800)),
              Text('100%', style: TextStyle(fontSize: 10.5, color: Colors.black.withAlpha(125), fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            windowLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.black.withAlpha(125), fontWeight: FontWeight.w800),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 420;
        return Material(
          color: Color.lerp(Colors.white, accent, 0.06),
          elevation: 2,
          shadowColor: accent.withAlpha(26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: accent.withAlpha(55)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned(
                  right: -6,
                  top: -6,
                  child: Icon(art, size: 70, color: accent.withAlpha(26)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(220),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: accent.withAlpha(70)),
                            ),
                            child: Icon(icon, color: accent.withAlpha(235), size: 26),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: portalSp(context, 12),
                                    color: AppTheme.textPrimary,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  etaLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: portalSp(context, 18),
                                    color: AppTheme.primaryPurple,
                                    height: 1.1,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: portalSp(context, 12),
                                    color: Colors.black.withAlpha(135),
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!narrow) ...[
                            const SizedBox(width: 10),
                            SizedBox(width: 150, child: rightMetrics()),
                          ],
                        ],
                      ),
                      if (narrow) ...[
                        const SizedBox(height: 10),
                        rightMetrics(),
                      ],
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

class _BabyBannerTimelineCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final Color softBg;
  final String title;
  final String value;
  final String subtitle;
  final double progress01;
  final String maxLabel;
  final bool exhausted;
  final VoidCallback? onTap;
  final bool dense;

  const _BabyBannerTimelineCard({
    required this.icon,
    required this.accent,
    required this.softBg,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.progress01,
    required this.maxLabel,
    this.exhausted = false,
    this.onTap,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final pad = dense ? const EdgeInsets.fromLTRB(10, 10, 10, 10) : const EdgeInsets.fromLTRB(12, 12, 12, 12);
    return Material(
      color: softBg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: accent.withAlpha(28))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(220),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withAlpha(70)),
                    ),
                    child: Icon(icon, color: accent.withAlpha(220), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: portalSp(context, 11.5), color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: portalSp(context, 16), color: accent),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: portalSp(context, 12), color: Colors.black.withAlpha(145), height: 1.2),
              ),
              const SizedBox(height: 10),
              _MiniTimeline(progress01: progress01, accent: accent, maxLabel: maxLabel, exhausted: exhausted),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTimeline extends StatelessWidget {
  final double progress01;
  final Color accent;
  final String maxLabel;
  final bool exhausted;

  const _MiniTimeline({required this.progress01, required this.accent, required this.maxLabel, this.exhausted = false});

  @override
  Widget build(BuildContext context) {
    final p = progress01.clamp(0.0, 1.0);
    final labels = maxLabel.trim() == '2h'
        ? const <String>['0h', '1h', '2h']
        : <String>['0h', '1h', '2h', maxLabel];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                return Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: Colors.black.withAlpha(10))),
                    Positioned(left: 0, top: 0, bottom: 0, width: w * p, child: ColoredBox(color: accent.withAlpha(170))),
                    Positioned(
                      left: (w * p).clamp(0.0, w - 10),
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle, boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 6, offset: const Offset(0, 2)),
                        ]),
                      ),
                    ),
                    if (exhausted)
                      Positioned(
                        right: -1,
                        top: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(55),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withAlpha(220), width: 1),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final l in labels)
              Text(l, style: TextStyle(fontSize: 10.5, color: Colors.black.withAlpha(125), fontWeight: FontWeight.w800)),
          ],
        ),
      ],
    );
  }
}

/// Atalhos no cartão do bebé: ícone à esquerda, textos à direita (uma linha com [Expanded]×3).
class _BabyQuickTile extends StatelessWidget {
  final bool narrow;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color tileBackground;
  final VoidCallback? onTap;

  const _BabyQuickTile({
    required this.narrow,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.tileBackground,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleFs = portalSp(context, narrow ? 9.5 : 10);
    final subFs = portalSp(context, narrow ? 8.5 : 9);
    final iconSz = narrow ? 17.0 : 19.0;
    final pad = EdgeInsets.fromLTRB(narrow ? 5 : 7, narrow ? 8 : 9, narrow ? 5 : 7, narrow ? 8 : 9);

    final inner = Container(
      width: double.infinity,
      padding: pad,
      decoration: BoxDecoration(
        color: tileBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: iconSz),
          SizedBox(width: narrow ? 5 : 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: titleFs,
                    height: 1.12,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: narrow ? 2 : 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: subFs,
                    height: 1.18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return inner;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: inner,
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color? softBg;
  final VoidCallback? onTap;

  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.softBg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleSize = portalSp(context, 14);
    final subSize = portalSp(context, 11.5);
    final iconBg = softBg ?? color.withAlpha(31);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: color.withAlpha(48),
            boxShadow: [
              BoxShadow(color: color.withAlpha(32), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          padding: const EdgeInsets.all(1.6),
          child: Material(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(24.6),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: color.withAlpha(35), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(child: Icon(icon, color: color, size: 22)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: titleSize * 0.96,
                      height: 1.05,
                      letterSpacing: -0.2,
                      color: Color.lerp(Colors.black87, color, 0.28),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: TextStyle(
                      color: color.withAlpha(210),
                      fontWeight: FontWeight.w800,
                      fontSize: subSize * 0.97,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? softBg;
  final Widget value;
  final String label;
  final String hint;

  const _TodaySummaryCard({
    required this.icon,
    required this.color,
    this.softBg,
    required this.value,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final baseTint = softBg ?? Color.lerp(AppTheme.background, color, 0.06)!;
    // Fundo único e suave — sem gradiente diagonal (evita aspecto de “reflexo” / brilho).
    final fill = Color.lerp(baseTint, AppTheme.card, 0.48)!;
    final mutedIcon = Color.lerp(AppTheme.textSecondary, color, 0.36)!;
    final iconBg = Color.lerp(fill, AppTheme.background, 0.55)!;
    final iconRadius = portalSp(context, 14).clamp(12.0, 16.0);
    final minH = portalSp(context, 92).clamp(82.0, 104.0);
    final valueStyle = TextStyle(
      fontSize: portalSp(context, 15.5),
      fontWeight: FontWeight.w900,
      height: 1.1,
      letterSpacing: -0.3,
      color: AppTheme.textSecondary.withAlpha(240),
    );
    final labelStyle = TextStyle(
      color: AppTheme.textSecondary.withAlpha(250),
      fontWeight: FontWeight.w900,
      fontSize: portalSp(context, 14.4),
      height: 1.05,
      letterSpacing: 0.35,
    );
    final hintStyle = TextStyle(
      color: AppTheme.textMuted,
      fontWeight: FontWeight.w600,
      fontSize: portalSp(context, 10.8),
      height: 1.05,
    );
    return Container(
      constraints: BoxConstraints(minHeight: minH),
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EF)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: iconRadius,
            backgroundColor: iconBg,
            child: Icon(icon, color: mutedIcon, size: portalSp(context, 16).clamp(14.0, 18.0)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, tc) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: labelStyle),
                    const SizedBox(height: 3),
                    DefaultTextStyle(style: valueStyle, child: value),
                    const SizedBox(height: 2),
                    Text(hint, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: hintStyle),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartão "Dica do dia" ao lado da saudação (layout referência Home).
class _HomeDailyTipCard extends StatelessWidget {
  final String title;
  final String text;

  const _HomeDailyTipCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4CC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD88A)),
        boxShadow: [
          BoxShadow(color: AppTheme.yellow.withAlpha(48), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2C2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.yellow.withAlpha(120)),
            ),
            child: const Icon(Icons.star_rounded, color: Color(0xFFFFB020), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: portalSp(context, 13),
                    color: AppTheme.primaryPurple,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.black.withAlpha(145),
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    fontSize: portalSp(context, 11.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _CriticalBannerAlertKind { feeding, sleep, diaper }

extension on _CriticalBannerAlertKind {
  int get priority => switch (this) {
        _CriticalBannerAlertKind.feeding => 0,
        _CriticalBannerAlertKind.sleep => 1,
        _CriticalBannerAlertKind.diaper => 2,
      };
}

class _CriticalBannerAlert {
  final _CriticalBannerAlertKind kind;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _CriticalBannerAlert({
    required this.kind,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
}

/// Aviso compacto de próxima consulta, acima da "Dica do dia".
class _HomeConsultationInlineAlert extends StatelessWidget {
  final String title;
  final DateTime when;
  final VoidCallback onTap;

  const _HomeConsultationInlineAlert({
    required this.title,
    required this.when,
    required this.onTap,
  });

  String _fmtWhen(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final red = Colors.red.shade700;
    return Material(
      color: Color.lerp(Colors.white, Colors.red, 0.06),
      elevation: 2,
      shadowColor: Colors.red.withAlpha(35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.red.withAlpha(55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: red, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.homeConsultationScheduled,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: red,
                        fontSize: portalSp(context, 12.5),
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_fmtWhen(when)} · $title',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: red.withAlpha(220),
                        fontSize: portalSp(context, 11.5),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dica do dia a partir de `assets/data/baby_daily_tips_500.json` (faixa etária); fallback i18n.
class _HomeDailyTipLoader extends StatefulWidget {
  final DateTime? birthDate;
  final int? babyId;
  final String title;
  final String fallbackBody;
  final AppLang lang;

  const _HomeDailyTipLoader({
    required this.birthDate,
    required this.babyId,
    required this.title,
    required this.fallbackBody,
    required this.lang,
  });

  @override
  State<_HomeDailyTipLoader> createState() => _HomeDailyTipLoaderState();
}

class _HomeDailyTipLoaderState extends State<_HomeDailyTipLoader> {
  late Future<String?> _future;

  @override
  void initState() {
    super.initState();
    _future = BabyDailyTipsService.tipTextForDay(
      birthDate: widget.birthDate,
      babyId: widget.babyId,
      now: DateTime.now(),
      lang: widget.lang,
    );
  }

  @override
  void didUpdateWidget(covariant _HomeDailyTipLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameCalendarDate(oldWidget.birthDate, widget.birthDate) ||
        oldWidget.babyId != widget.babyId ||
        oldWidget.lang != widget.lang) {
      setState(() {
        _future = BabyDailyTipsService.tipTextForDay(
          birthDate: widget.birthDate,
          babyId: widget.babyId,
          now: DateTime.now(),
          lang: widget.lang,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snap) {
        final custom = snap.hasError ? null : snap.data?.trim();
        final text = (custom != null && custom.isNotEmpty) ? custom : widget.fallbackBody;
        return _HomeDailyTipCard(title: widget.title, text: text);
      },
    );
  }
}

class _HomeMotivationBanner extends StatelessWidget {
  final String text;
  final String linkLabel;
  final VoidCallback onOpenMemories;

  const _HomeMotivationBanner({
    required this.text,
    required this.linkLabel,
    required this.onOpenMemories,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: linkLabel,
      child: Material(
        color: Color.lerp(const Color(0xFFF5F0FC), AppTheme.primaryPurple, 0.04)!,
        elevation: 3,
        shadowColor: AppTheme.primaryPurple.withAlpha(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: AppTheme.primaryPurple.withAlpha(40)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpenMemories,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(230),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_rounded, color: AppTheme.primaryPurple, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: portalSp(context, 13),
                          height: 1.35,
                          color: AppTheme.primaryPurple.withAlpha(245),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            linkLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: portalSp(context, 12),
                              color: AppTheme.primaryPurple,
                              decoration: TextDecoration.underline,
                              decorationColor: AppTheme.primaryPurple.withAlpha(200),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.primaryPurple.withAlpha(230)),
                        ],
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/sleep/baby_sleep.png',
                    height: 68,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 8, height: 68),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DevelopmentLeapHomeCard extends StatelessWidget {
  final VoidCallback onOpen;

  const _DevelopmentLeapHomeCard({required this.onOpen});

  String _babyName(S s) {
    final n = (CurrentBabyController.instance.currentBabyRow?['name'] as String?)?.trim();
    return (n == null || n.isEmpty) ? s.baby : n;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final name = _babyName(s);
    final birthRaw = CurrentBabyController.instance.currentBabyRow?['birth_date'] as String?;
    final birth = DateTime.tryParse((birthRaw ?? '').trim());
    if (birth == null) return const SizedBox.shrink();

    final leap = DevelopmentLeapsService.current(birthDate: birth);
    if (leap == null) return const SizedBox.shrink();

    final bk = leap.bannerKey;
    final rangeLbl = s.developmentLeapBannerRange(bk);
    final titleLbl = s.developmentLeapBannerTitle(bk);
    final lead = s.developmentLeapBannerLead(bk).replaceAll('{baby_name}', name);
    final emoLine = s.developmentLeapBannerEmotion(bk);
    const pink = AppTheme.primaryPink;

    return Material(
      color: Color.lerp(Colors.white, pink, 0.06),
      elevation: 1.5,
      shadowColor: pink.withAlpha(30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: pink.withAlpha(55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FloatingCloud(accent: pink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titleLbl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black.withAlpha(165)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: pink.withAlpha(26),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            rangeLbl,
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: pink.withAlpha(230)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lead,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, height: 1.25, color: Colors.black.withAlpha(150)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '💜 $emoLine',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black.withAlpha(145)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s.devLeapsSeeDetails,
                          style: TextStyle(fontWeight: FontWeight.w900, color: pink.withAlpha(240)),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, size: 18, color: pink.withAlpha(240)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingCloud extends StatefulWidget {
  final Color accent;

  const _FloatingCloud({required this.accent});

  @override
  State<_FloatingCloud> createState() => _FloatingCloudState();
}

class _FloatingCloudState extends State<_FloatingCloud> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))..repeat(reverse: true);
  late final Animation<double> _dy = Tween<double>(begin: -0.02, end: 0.02).animate(
    CurvedAnimation(parent: _c, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pink = widget.accent;
    return AnimatedBuilder(
      animation: _dy,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, _dy.value * 60),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: pink.withAlpha(22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pink.withAlpha(60)),
            ),
            child: Icon(Icons.cloud_rounded, color: pink.withAlpha(235), size: 24),
          ),
        );
      },
    );
  }
}
