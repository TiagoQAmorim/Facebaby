import 'dart:async' show unawaited;
import 'package:flutter/material.dart';

import '../utils/app_date_picker.dart';

import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../models/daily_summary.dart';
import '../models/family_message_prefs.dart';
import '../services/app_database.dart';
import '../services/family_christian_content_service.dart'
    show FamilyChristianContentService;
import '../services/family_phrase_content_service.dart';
import '../services/family_zodiac_content_service.dart'
    show FamilyZodiacContentService;
import '../services/family_homily_read_prefs.dart';
import '../services/family_horoscope_read_prefs.dart';
import '../services/premium/feature_access.dart';
import '../services/premium/premium_service.dart';
import '../services/app_tour/app_tour_keys.dart';
import '../theme/app_theme.dart';
import '../utils/family_page_tabs.dart';
import '../utils/portal_page_route.dart';
import '../utils/portal_time_of_day.dart';
import '../widgets/family_ai_baby_history_panel.dart';
import '../widgets/family_homily_panel.dart';
import '../widgets/family_horoscope_panel.dart';
import '../widgets/family_tree_stage.dart';
import 'mother_profile_page.dart';
import 'premium/premium_paywall_screen.dart';

/// Tela «Família»: árvore ilustrada e cartões por membro (`FamilyTreeStage`).
class FamilyTreePage extends StatefulWidget {
  const FamilyTreePage({
    super.key,
    this.initialTabIndex = 0,
    this.tourMode = false,
  });

  /// Índice da guia superior ([FamilyPageTabs]).
  final int initialTabIndex;

  /// Versão simplificada para o tour do app (sem abas nem configurações).
  final bool tourMode;

  @override
  State<FamilyTreePage> createState() => _FamilyTreePageState();
}

class _FamilyTreePageState extends State<FamilyTreePage>
    with SingleTickerProviderStateMixin {
  final _current = CurrentBabyController.instance;
  late TabController _tabController;
  DateTime _selectedSummaryDay = _dateOnly(DateTime.now());
  Map<int, double> _heightByBabyId = {};
  bool _zodiacContentReady = false;
  bool _christianContentReady = false;
  bool _spiritistContentReady = false;
  bool _jewishContentReady = false;
  FamilyMessagePrefs _messagePrefs = FamilyMessagePrefs.horoscopeOnly;
  /// Gera conteúdo IA só depois que a mãe abre a guia correspondente.
  bool _homilyGenerationRequested = false;
  bool _horoscopeGenerationRequested = false;
  List<Map<String, Object?>> _babies = [];
  DailySummary? _todaySummary;
  DateTime? _lastFeedEndedAt;
  DateTime? _lastDiaperChangedAt;
  DateTime? _lastSleepEndedAt;

  bool get _showAiFamilyContent => FeatureAccess.canUseAnyAi;

  FamilyMessagePrefs get _displayMessagePrefs =>
      _showAiFamilyContent ? _messagePrefs : FamilyMessagePrefs.none;

  int get _tabCount => FamilyPageTabs.tabCount(
        _displayMessagePrefs,
        showAiHistory: _showAiFamilyContent,
      );

  @override
  void initState() {
    super.initState();
    _messagePrefs = FamilyMessagePrefs.fromMother(_current.currentMotherRow);
    final initialTab = widget.initialTabIndex.clamp(0, _tabCount - 1);
    if (FamilyPageTabs.homily(_displayMessagePrefs) == initialTab) {
      _homilyGenerationRequested = true;
    }
    if (FamilyPageTabs.horoscope(_displayMessagePrefs) == initialTab) {
      _horoscopeGenerationRequested = true;
    }
    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: initialTab,
    );
    _tabController.addListener(_onFamilyTopTabChanged);
    _current.addListener(_onDataChanged);
    PremiumService.instance.addListener(_onPremiumChanged);
    unawaited(_loadBabyHeightsForFamily());
    unawaited(_loadFamilyMetrics());
    _loadZodiacContentIfPremium();
    _loadChristianContentIfNeeded();
    _loadSpiritistContentIfNeeded();
    _loadJewishContentIfNeeded();
    unawaited(FamilyHomilyUnreadBadge.refresh());
    unawaited(FamilyHoroscopeUnreadBadge.refresh());
  }

  void _onFamilyTopTabChanged() {
    if (_tabController.indexIsChanging) return;
    final idx = _tabController.index;
    var changed = false;
    if (FamilyPageTabs.homily(_displayMessagePrefs) == idx &&
        !_homilyGenerationRequested) {
      _homilyGenerationRequested = true;
      changed = true;
    }
    if (FamilyPageTabs.horoscope(_displayMessagePrefs) == idx &&
        !_horoscopeGenerationRequested) {
      _horoscopeGenerationRequested = true;
      changed = true;
    }
    if (changed && mounted) setState(() {});
  }

  int _mapTabIndexAfterCountChange(int oldIndex, int oldLen, int newLen) {
    if (oldLen == newLen) return oldIndex;
    if (oldIndex == 0) return 0;
    if (newLen <= 1) return 0;
    return (oldIndex >= newLen - 1) ? newLen - 1 : oldIndex;
  }

  void _recreateTabControllerIfNeeded() {
    final want = _tabCount;
    if (_tabController.length == want) return;
    final oldLen = _tabController.length;
    final oldIdx = _tabController.index;
    _tabController.removeListener(_onFamilyTopTabChanged);
    _tabController.dispose();
    final nextIdx =
        _mapTabIndexAfterCountChange(oldIdx, oldLen, want).clamp(0, want - 1);
    _tabController = TabController(
      length: want,
      vsync: this,
      initialIndex: nextIdx,
    );
    _tabController.addListener(_onFamilyTopTabChanged);
    if (!_messagePrefs.showHoroscope) {
      FamilyHoroscopeUnreadBadge.show.value = false;
    }
    if (!_messagePrefs.showChristian) {
      FamilyHomilyUnreadBadge.show.value = false;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onFamilyTopTabChanged);
    _tabController.dispose();
    _current.removeListener(_onDataChanged);
    PremiumService.instance.removeListener(_onPremiumChanged);
    super.dispose();
  }

  void _onPremiumChanged() {
    _loadZodiacContentIfPremium();
    unawaited(FamilyHomilyUnreadBadge.refresh());
    unawaited(FamilyHoroscopeUnreadBadge.refresh());
    _recreateTabControllerIfNeeded();
    if (mounted) setState(() {});
  }

  void _syncMessagePrefs() {
    _messagePrefs = FamilyMessagePrefs.fromMother(_current.currentMotherRow);
    _recreateTabControllerIfNeeded();
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

  void _loadSpiritistContentIfNeeded() {
    if (!_messagePrefs.showSpiritist) return;
    FamilyPhraseContentService.spiritist.ensureLoaded().then((_) {
      if (mounted) setState(() => _spiritistContentReady = true);
    });
  }

  void _loadJewishContentIfNeeded() {
    if (!_messagePrefs.showJewish) return;
    FamilyPhraseContentService.jewish.ensureLoaded().then((_) {
      if (mounted) setState(() => _jewishContentReady = true);
    });
  }

  void _onDataChanged() {
    if (mounted) {
      _syncMessagePrefs();
      unawaited(FamilyHomilyUnreadBadge.refresh());
      unawaited(FamilyHoroscopeUnreadBadge.refresh());
      setState(() {});
      unawaited(_loadBabyHeightsForFamily());
      unawaited(_loadFamilyMetrics());
      _loadChristianContentIfNeeded();
      _loadSpiritistContentIfNeeded();
      _loadJewishContentIfNeeded();
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
    final picked = await showAppDatePicker(
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
    if (_messagePrefs.showHoroscope) {
      unawaited(FamilyHoroscopeUnreadBadge.refresh());
    }
    if (_messagePrefs.showChristian) {
      unawaited(FamilyHomilyUnreadBadge.refresh());
    }
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

  Widget _buildFamilyTreeStage({
    required S s,
    required Map<String, Object?>? mother,
    required bool fatherRegistered,
    required int? babyId,
    required bool zodiacUnlocked,
  }) {
    return FamilyTreeStage(
      s: s,
      zodiacUnlocked: zodiacUnlocked,
      zodiacReady: _zodiacContentReady,
      showChristianMessages: _displayMessagePrefs.showChristian,
      showHoroscopeMessages: _displayMessagePrefs.showHoroscope,
      showSpiritistMessages: _displayMessagePrefs.showSpiritist,
      showJewishMessages: _displayMessagePrefs.showJewish,
      christianReady: _christianContentReady,
      spiritistReady: _spiritistContentReady,
      jewishReady: _jewishContentReady,
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
      onEditMother: () => _openMyProfile(MotherProfileInitialTab.mother),
      onEditFather: () => _openMyProfile(MotherProfileInitialTab.father),
      onEditBaby: (id) async {
        await _current.setCurrentBabyId(id);
        if (!mounted) return;
        await _openMyProfile(MotherProfileInitialTab.babies);
      },
      premiumZodiacLockedMessage: s.familyPremiumZodiacLocked,
      premiumUnlockCta: s.familyPremiumUnlockCta,
      onPremiumTap: () => openPremiumPaywall(context),
      todaySummary: _todaySummary,
      summaryDay: _selectedSummaryDay,
      summaryDayLabel: _fmtCalendarDate(_selectedSummaryDay),
      isTodaySummaryDay: _isTodaySummaryDay,
      onPickSummaryDay: _pickSummaryDay,
      onTodaySummaryDay: _goToTodaySummary,
      lastFeedEndedAt: _lastFeedEndedAt,
      lastDiaperChangedAt: _lastDiaperChangedAt,
      lastSleepEndedAt: _lastSleepEndedAt,
    );
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

    // Espaço extra: botão central IA Babá sobrepõe o conteúdo da barra inferior.
    final tabScrollBottom =
        48.0 + MediaQuery.paddingOf(context).bottom + 20.0;
    final atNight = PortalTimeOfDay.isNight(DateTime.now());
    final fallback =
        atNight ? const Color(0xFF152238) : const Color(0xFFB8D9EE);

    return PopScope(
      canPop: !widget.tourMode,
      child: Scaffold(
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
                final tabPadding =
                    EdgeInsets.fromLTRB(20, 0, 20, tabScrollBottom);

                Widget tabScroll({required Widget child}) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      padding: tabPadding,
                      child: child,
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          KeyedSubtree(
                            key: AppTourKeys.familyTourHeader,
                            child: _FamilyPageHeader(
                              title: s.familyScreenTitle,
                              settingsTooltip: s.settingsTitle,
                              onBack: () => Navigator.maybePop(context),
                              hideBack: widget.tourMode,
                              onSettings: widget.tourMode || motherId == null
                                  ? null
                                  : () => _openMyProfile(
                                        MotherProfileInitialTab.preferences,
                                      ),
                            ),
                          ),
                          if (!widget.tourMode) ...[
                            const SizedBox(height: 8),
                            TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            labelColor: atNight
                                ? PortalTimeOfDay.nightOutlinedTextColor
                                : const Color(0xFF6A1B9A),
                            unselectedLabelColor: atNight
                                ? PortalTimeOfDay.nightOutlinedTextColor
                                    .withAlpha(200)
                                : Colors.black.withAlpha(120),
                            indicatorColor: atNight
                                ? PortalTimeOfDay.nightOutlinedTextColor
                                : AppTheme.primaryPink,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                            tabs: [
                              Tab(text: s.familyTabTree),
                              if (_displayMessagePrefs.showChristian)
                                ValueListenableBuilder<bool>(
                                  valueListenable:
                                      FamilyHomilyUnreadBadge.show,
                                  builder: (context, unread, _) => Tab(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(s.familyTabHomily),
                                        if (unread) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '!',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              color: Colors.red.shade700,
                                              height: 1,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              if (_displayMessagePrefs.showHoroscope)
                                ValueListenableBuilder<bool>(
                                  valueListenable:
                                      FamilyHoroscopeUnreadBadge.show,
                                  builder: (context, unread, _) => Tab(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(s.familyTabHoroscope),
                                        if (unread) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '!',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              color: Colors.red.shade700,
                                              height: 1,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              if (_showAiFamilyContent)
                                Tab(text: s.familyTabAiHistory),
                            ],
                          ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.tourMode) const SizedBox(height: 12),
                    Expanded(
                      child: mother == null
                          ? Padding(
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
                          : widget.tourMode
                              ? tabScroll(
                                  child: KeyedSubtree(
                                    key: AppTourKeys.familyTree,
                                    child: _buildFamilyTreeStage(
                                      s: s,
                                      mother: mother,
                                      fatherRegistered: fatherRegistered,
                                      babyId: babyId,
                                      zodiacUnlocked: zodiacUnlocked,
                                    ),
                                  ),
                                )
                              : TabBarView(
                              controller: _tabController,
                              children: [
                                tabScroll(
                                  child: KeyedSubtree(
                                    key: AppTourKeys.familyTree,
                                    child: _buildFamilyTreeStage(
                                      s: s,
                                      mother: mother,
                                      fatherRegistered: fatherRegistered,
                                      babyId: babyId,
                                      zodiacUnlocked: zodiacUnlocked,
                                    ),
                                  ),
                                ),
                                if (_displayMessagePrefs.showChristian)
                                  tabScroll(
                                    child: FamilyHomilyPanel(
                                      requestGeneration:
                                          _homilyGenerationRequested,
                                    ),
                                  ),
                                if (_displayMessagePrefs.showHoroscope)
                                  tabScroll(
                                    child: FamilyHoroscopePanel(
                                      requestGeneration:
                                          _horoscopeGenerationRequested,
                                      fatherRegistered: fatherRegistered,
                                      onRegisterFather: () => _openMyProfile(
                                        MotherProfileInitialTab.father,
                                      ),
                                    ),
                                  ),
                                if (_showAiFamilyContent)
                                  tabScroll(
                                    child: const FamilyAiBabyHistoryPanel(),
                                  ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
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
    this.hideBack = false,
  });

  final String title;
  final String settingsTooltip;
  final VoidCallback onBack;
  final VoidCallback? onSettings;
  final bool hideBack;

  @override
  Widget build(BuildContext context) {
    final night = PortalTimeOfDay.isNight(DateTime.now());
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!hideBack)
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
