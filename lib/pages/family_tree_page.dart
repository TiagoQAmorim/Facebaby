import 'dart:async' show unawaited;
import 'package:flutter/material.dart';

import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../models/daily_summary.dart';
import '../models/family_message_prefs.dart';
import '../services/app_database.dart';
import '../services/family_christian_content_service.dart'
    show FamilyChristianContentService;
import '../services/family_zodiac_content_service.dart'
    show FamilyZodiacContentService;
import '../services/premium/feature_access.dart';
import '../services/premium/premium_service.dart';
import '../theme/app_theme.dart';
import '../utils/portal_page_route.dart';
import '../utils/portal_time_of_day.dart';
import '../widgets/family_tree_stage.dart';
import 'mother_profile_page.dart';
import 'premium/premium_paywall_screen.dart';

/// Tela «Família»: árvore ilustrada e cartões por membro (`FamilyTreeStage`).
class FamilyTreePage extends StatefulWidget {
  const FamilyTreePage({super.key});

  @override
  State<FamilyTreePage> createState() => _FamilyTreePageState();
}

class _FamilyTreePageState extends State<FamilyTreePage> {
  final _current = CurrentBabyController.instance;
  DateTime _selectedSummaryDay = _dateOnly(DateTime.now());
  Map<int, double> _heightByBabyId = {};
  bool _zodiacContentReady = false;
  bool _christianContentReady = false;
  FamilyMessagePrefs _messagePrefs = FamilyMessagePrefs.horoscopeOnly;
  List<Map<String, Object?>> _babies = [];
  DailySummary? _todaySummary;
  DateTime? _lastFeedEndedAt;
  DateTime? _lastDiaperChangedAt;
  DateTime? _lastSleepEndedAt;

  @override
  void initState() {
    super.initState();
    _current.addListener(_onDataChanged);
    PremiumService.instance.addListener(_onPremiumChanged);
    _syncMessagePrefs();
    unawaited(_loadBabyHeightsForFamily());
    unawaited(_loadFamilyMetrics());
    _loadZodiacContentIfPremium();
    _loadChristianContentIfNeeded();
  }

  @override
  void dispose() {
    _current.removeListener(_onDataChanged);
    PremiumService.instance.removeListener(_onPremiumChanged);
    super.dispose();
  }

  void _onPremiumChanged() {
    _loadZodiacContentIfPremium();
    if (mounted) setState(() {});
  }

  void _syncMessagePrefs() {
    _messagePrefs = FamilyMessagePrefs.fromMother(_current.currentMotherRow);
  }

  void _loadZodiacContentIfPremium() {
    if (!FeatureAccess.canViewFamilyZodiac) return;
    FamilyZodiacContentService.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _zodiacContentReady = true);
    });
  }

  void _loadChristianContentIfNeeded() {
    if (!_messagePrefs.showChristian) return;
    FamilyChristianContentService.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _christianContentReady = true);
    });
  }

  void _onDataChanged() {
    if (mounted) {
      _syncMessagePrefs();
      setState(() {});
      unawaited(_loadBabyHeightsForFamily());
      unawaited(_loadFamilyMetrics());
      _loadChristianContentIfNeeded();
    }
  }

  Future<void> _loadBabyHeightsForFamily() async {
    final mother = _current.currentMotherRow;
    final motherId = (mother?['id'] as num?)?.toInt();
    if (motherId == null) {
      if (!mounted) return;
      setState(() {
        _heightByBabyId = {};
        _babies = [];
      });
      return;
    }
    final all = await AppDatabase.instance.listBabies();
    final babies = all
        .where((b) => (b['mother_id'] as num?)?.toInt() == motherId)
        .toList();
    final heights = <int, double>{};
    for (final b in babies) {
      final id = (b['id'] as num?)?.toInt();
      if (id == null) continue;
      final rows = await AppDatabase.instance.listGrowthRecords(
        babyId: id,
        kind: 'height',
        limit: 1,
      );
      double? h;
      if (rows.isNotEmpty) {
        h = (rows.first['value'] as num?)?.toDouble();
      }
      h ??= (b['height_cm'] as num?)?.toDouble();
      if (h != null && h > 0) heights[id] = h;
    }
    if (!mounted) return;
    setState(() {
      _heightByBabyId = heights;
      _babies = babies;
    });
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _isTodaySummaryDay =>
      _selectedSummaryDay == _dateOnly(DateTime.now());

  String _fmtCalendarDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickSummaryDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedSummaryDay.isAfter(_dateOnly(now))
          ? _dateOnly(now)
          : _selectedSummaryDay,
      firstDate: DateTime(2020),
      lastDate: _dateOnly(now),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedSummaryDay = _dateOnly(picked));
    await _loadFamilyMetrics();
  }

  Future<void> _goToTodaySummary() async {
    setState(() => _selectedSummaryDay = _dateOnly(DateTime.now()));
    await _loadFamilyMetrics();
  }

  Future<void> _loadFamilyMetrics() async {
    final id = _current.currentBabyId;
    if (id == null) {
      if (!mounted) return;
      setState(() {
        _todaySummary = null;
        _lastFeedEndedAt = null;
        _lastDiaperChangedAt = null;
        _lastSleepEndedAt = null;
      });
      return;
    }
    final day = _selectedSummaryDay;
    try {
      final r = await Future.wait<Object?>([
        AppDatabase.instance.latestBreastOrBottleFeedingEndedOnCalendarDay(
            babyId: id, calendarDay: day),
        AppDatabase.instance
            .latestDiaperChangedAtOnCalendarDay(babyId: id, calendarDay: day),
        AppDatabase.instance
            .latestCompletedSleepEndOnCalendarDay(babyId: id, calendarDay: day),
        AppDatabase.instance
            .dailySummaryForHomePicker(babyId: id, calendarDay: day),
      ]);
      if (!mounted) return;
      setState(() {
        _lastFeedEndedAt = r[0] as DateTime?;
        _lastDiaperChangedAt = r[1] as DateTime?;
        _lastSleepEndedAt = r[2] as DateTime?;
        _todaySummary = r[3] as DailySummary;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _todaySummary = null;
        _lastFeedEndedAt = null;
        _lastDiaperChangedAt = null;
        _lastSleepEndedAt = null;
      });
    }
  }

  Future<void> _refresh() async {
    await _current.refresh();
    _syncMessagePrefs();
    await _loadBabyHeightsForFamily();
    await _loadFamilyMetrics();
    _loadChristianContentIfNeeded();
  }

  Future<void> _openMyProfile(MotherProfileInitialTab tab) async {
    await pushPortalPage<void>(
      context,
      MotherProfilePage(initialTab: tab),
    );
    await _refresh();
  }

  int _initialTabIndex({
    required bool fatherRegistered,
    required int? currentBabyId,
  }) {
    if (currentBabyId == null) return 0;
    final babyIdx =
        _babies.indexWhere((b) => (b['id'] as num?)?.toInt() == currentBabyId);
    if (babyIdx < 0) return 0;
    final offset = fatherRegistered ? 2 : 1;
    return offset + babyIdx;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final mother = _current.currentMotherRow;
    final baby = _current.currentBabyRow;
    final motherId = (mother?['id'] as num?)?.toInt();
    final babyId = (baby?['id'] as num?)?.toInt();
    final fatherRegistered =
        mother != null && motherProfileFatherRegistered(mother);
    final zodiacUnlocked = FeatureAccess.canViewFamilyZodiac;

    final bottomPadding = MediaQuery.of(context).padding.bottom + 140;
    final atNight = PortalTimeOfDay.isNight(DateTime.now());
    final fallback =
        atNight ? const Color(0xFF152238) : const Color(0xFFB8D9EE);

    return Scaffold(
      // O MainShell já mantém o background do portal em cache atrás do Navigator.
      // Evita recriar a mesma imagem ao abrir/fechar Família, que causava flash.
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: fallback.withAlpha(18)),
          SafeArea(
            child: ListenableBuilder(
              listenable: PremiumService.instance,
              builder: (context, _) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 10, 20, bottomPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FamilyPageHeader(
                          title: s.familyScreenTitle,
                          settingsTooltip: s.settingsTitle,
                          onBack: () => Navigator.maybePop(context),
                          onSettings: motherId == null
                              ? null
                              : () => _openMyProfile(
                                    MotherProfileInitialTab.preferences,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        if (mother == null)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              s.motherProfileNoData,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          FamilyTreeStage(
                            s: s,
                            zodiacUnlocked: zodiacUnlocked,
                            zodiacReady: _zodiacContentReady,
                            showChristianMessages: _messagePrefs.showChristian,
                            showHoroscopeMessages: _messagePrefs.showHoroscope,
                            christianReady: _christianContentReady,
                            mother: mother,
                            babies: _babies,
                            heightCmByBabyId: _heightByBabyId,
                            fatherRegistered: fatherRegistered,
                            activeBabyId: babyId,
                            initialTabIndex: _initialTabIndex(
                              fatherRegistered: fatherRegistered,
                              currentBabyId: babyId,
                            ),
                            verticalMemberTabs: false,
                            onEditMother: () =>
                                _openMyProfile(MotherProfileInitialTab.mother),
                            onEditFather: () =>
                                _openMyProfile(MotherProfileInitialTab.father),
                            onEditBaby: (id) async {
                              await _current.setCurrentBabyId(id);
                              if (!mounted) return;
                              await _openMyProfile(
                                MotherProfileInitialTab.babies,
                              );
                            },
                            premiumZodiacLockedMessage:
                                s.familyPremiumZodiacLocked,
                            premiumUnlockCta: s.familyPremiumUnlockCta,
                            onPremiumTap: () => openPremiumPaywall(context),
                            todaySummary: _todaySummary,
                            summaryDay: _selectedSummaryDay,
                            summaryDayLabel:
                                _fmtCalendarDate(_selectedSummaryDay),
                            isTodaySummaryDay: _isTodaySummaryDay,
                            onPickSummaryDay: _pickSummaryDay,
                            onTodaySummaryDay: _goToTodaySummary,
                            lastFeedEndedAt: _lastFeedEndedAt,
                            lastDiaperChangedAt: _lastDiaperChangedAt,
                            lastSleepEndedAt: _lastSleepEndedAt,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyPageHeader extends StatelessWidget {
  const _FamilyPageHeader({
    required this.title,
    required this.settingsTooltip,
    required this.onBack,
    this.onSettings,
  });

  final String title;
  final String settingsTooltip;
  final VoidCallback onBack;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final night = PortalTimeOfDay.isNight(DateTime.now());
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _HeaderIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onPressed: onBack,
            ),
          ),
          Center(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: night
                    ? PortalTimeOfDay.nightOutlinedTextColor
                    : AppTheme.textPrimary,
                shadows: night ? PortalTimeOfDay.nightTextOutlineShadows : null,
                height: 1.05,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: onSettings == null
                ? const SizedBox(width: 42, height: 42)
                : _HeaderIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: settingsTooltip,
                    onPressed: onSettings!,
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        iconSize: 26,
        color: AppTheme.textPrimary,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}
