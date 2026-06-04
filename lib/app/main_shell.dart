import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_locale.dart';
import '../controllers/ai_controller.dart';
import '../controllers/current_baby_controller.dart';
import '../controllers/sleep_timer_controller.dart';
import '../i18n/app_i18n.dart';
import '../models/baby.dart';
import '../pages/home_page.dart';
import '../pages/quick_register_page.dart';
import '../pages/settings_page.dart';
import '../pages/ai/ai_nanny_screen.dart';
import '../pages/memories/memories_page.dart' as new_memories;
import '../widgets/shell_bottom_navigation.dart';
import '../services/mock_baby_service.dart';
import '../utils/pick_image_b64.dart';
import '../utils/portal_page_route.dart';
import '../utils/portal_time_of_day.dart';
import '../services/app_database.dart';
import '../services/home_prefs.dart';
import '../services/portal_layout_prefs.dart';
import '../services/local_notifications_service.dart';
import '../services/reminder_monitor.dart';
import '../services/update_service.dart';
import '../widgets/app_update_banner.dart';
import '../services/ai/family_daily_prefetch.dart';
import '../services/scheduled_local_reminders.dart';
import '../services/firebase/profile_cloud_sync.dart';
import '../services/measurement_units_prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_overlay.dart';
import '../widgets/loading_scope.dart';
import '../widgets/loading_navigator_observer.dart';
import '../widgets/weekly_photo_winner_congrats_host.dart';
import '../widgets/ai/ai_nanny_bubble_host.dart';
import '../services/premium/feature_access.dart';
import '../services/premium/premium_service.dart';
import '../pages/premium/premium_paywall_screen.dart';
import 'shell_nested_nav.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  static const int _recordsTabIndex = 1;

  final AiController aiController = AiController();
  final MockBabyService babyService = MockBabyService();
  final CurrentBabyController currentBaby = CurrentBabyController.instance;
  int selectedIndex = 0;
  final ValueNotifier<int> _homeRouteDepth = ValueNotifier<int>(0);
  final ScrollController _homeScrollController = ScrollController();
  late final List<_ShellTabRouteObserver> _tabRouteObservers;
  late final VoidCallback _aiMicListener;
  late final VoidCallback _onBabyChangedPopNavigators;

  /// Ao mudar de bebé, repõe cada separador à raiz para não ficar um ecrã “do outro” filho aberto.
  int? _lastBabyIdForNavCleanup;

  /// Usado para ignorar um “back” fantasma logo após voltar da galeria / file picker (Android).
  DateTime? _lastShellResumeAt;
  Timer? _portalBgTimer;
  bool _didPrecachePortalBackgrounds = false;

  void _schedulePortalBackgroundRefresh() {
    _portalBgTimer?.cancel();
    if (PortalLayoutPrefs.instance.mode != PortalLayoutMode.automatic) return;
    _portalBgTimer = Timer(
      PortalTimeOfDay.delayUntilNextTransition(DateTime.now()),
      () {
        if (!mounted) return;
        setState(() {});
        _schedulePortalBackgroundRefresh();
      },
    );
  }

  void _onPortalLayoutPrefsChanged() {
    _schedulePortalBackgroundRefresh();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedulePortalBackgroundRefresh();
    PortalLayoutPrefs.instance.addListener(_onPortalLayoutPrefsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocalNotificationsService.instance.requestPermissionOnceOnFirstLaunch();
      unawaited(UpdateService.instance.checkForUpdateIfNeeded());
      FamilyDailyPrefetch.scheduleIfNeeded(S(kAppLanguage.lang));
    });
    unawaited(_bootstrapRemindersPipeline());
    _aiMicListener = () {
      if (!HomePrefs.aiMicEnabled.value && aiController.isActive) {
        aiController.close();
      }
    };
    HomePrefs.aiMicEnabled.addListener(_aiMicListener);
    ShellNestedNav.selectTab = _goToTab;
    _tabRouteObservers = List<_ShellTabRouteObserver>.generate(
      5,
      (i) => _ShellTabRouteObserver(
        tabIndex: i,
        onDepthChanged: _onTabRouteDepthChanged,
      ),
    );

    _lastBabyIdForNavCleanup = currentBaby.currentBabyId;
    _onBabyChangedPopNavigators = _popAllTabsToRootOnBabySwitch;
    currentBaby.addListener(_onBabyChangedPopNavigators);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecachePortalBackgrounds) return;
    _didPrecachePortalBackgrounds = true;
    unawaited(PortalTimeOfDay.precacheBackgrounds(context));
  }

  void _popAllTabsToRootOnBabySwitch() {
    final id = currentBaby.currentBabyId;
    if (id != null &&
        _lastBabyIdForNavCleanup != null &&
        id != _lastBabyIdForNavCleanup) {
      for (var i = 0; i < 5; i++) {
        _popTabToRoot(i);
      }
    }
    if (id != null) {
      _lastBabyIdForNavCleanup = id;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Última oportunidade antes do SO suspender o isolate: regravar alarmes no AlarmManager.
      // Sem isto, em alguns equipamentos só o `show()` ao voltar a abrir parece “funcionar”.
      final bid = currentBaby.currentBabyId;
      unawaited(ScheduledLocalReminders.sync(babyId: bid));
    }
    if (state == AppLifecycleState.resumed) {
      _lastShellResumeAt = DateTime.now();
      if (mounted) {
        setState(() {});
        _schedulePortalBackgroundRefresh();
      }
      // Após segundo plano: re-sincroniza bebê/mãe na BD (evita UI “sem cadastro” por estado stale).
      unawaited(currentBaby.refresh());
      // Reagenda lembretes locais (não depender só da Home puxada para refresh).
      ReminderMonitor.instance.onAppResumed();
      unawaited(UpdateService.instance.checkForUpdateIfNeeded());
      FamilyDailyPrefetch.scheduleIfNeeded(S(kAppLanguage.lang));
    }
  }

  /// Garante bebê + prefs carregados antes de [ReminderMonitor] — evita o primeiro [sync] com
  /// `babyId == null` cancelar todos os lembretes agendados no SO.
  Future<void> _bootstrapRemindersPipeline() async {
    try {
      await currentBaby.init();
    } catch (e, st) {
      debugPrint('MainShell: currentBaby.init failed: $e\n$st');
    }
    try {
      await SleepTimerController.instance.init();
    } catch (e, st) {
      debugPrint('MainShell: SleepTimerController.init failed: $e\n$st');
    }
    try {
      await HomePrefs.init();
    } catch (e, st) {
      debugPrint('MainShell: HomePrefs.init failed: $e\n$st');
    }
    try {
      await PortalLayoutPrefs.init();
    } catch (e, st) {
      debugPrint('MainShell: PortalLayoutPrefs.init failed: $e\n$st');
    }
    if (!mounted) return;
    ReminderMonitor.instance.start();
  }

  void _goToTab(int index) {
    if (!mounted) return;
    setState(() {
      selectedIndex = index.clamp(0, 4);
    });
  }

  void _onTabRouteDepthChanged(int tabIndex, int depth) {
    if (!mounted) return;
    if (tabIndex != 0 || _homeRouteDepth.value == depth) return;
    _homeRouteDepth.value = depth;
  }

  @override
  void dispose() {
    _portalBgTimer?.cancel();
    PortalLayoutPrefs.instance.removeListener(_onPortalLayoutPrefsChanged);
    WidgetsBinding.instance.removeObserver(this);
    ShellNestedNav.selectTab = null;
    HomePrefs.aiMicEnabled.removeListener(_aiMicListener);
    currentBaby.removeListener(_onBabyChangedPopNavigators);
    _homeScrollController.dispose();
    _homeRouteDepth.dispose();
    aiController.dispose();
    ReminderMonitor.instance.stop();
    super.dispose();
  }

  void _popRecordsTabToRoot() {
    _popTabToRoot(_recordsTabIndex);
  }

  /// Volta à raiz do separador (única rota `'/'`), para o ícone do nav corresponder ao ecrã visível.
  void _popTabToRoot(int tabIndex) {
    ShellNestedNav.tabNavigatorKeys[tabIndex].currentState
        ?.popUntil((route) => route.isFirst);
  }

  void openQuickRegister() {
    _popRecordsTabToRoot();
    setState(() => selectedIndex = _recordsTabIndex);
  }

  void _onDestinationSelected(int index) {
    if (index == 2 && !FeatureAccess.canUseAnyAi) {
      openPremiumPaywall(context);
      return;
    }
    // Sem isto, ao voltar ao Início o [selectedIndex] pode ser 0 mas o topo da pilha continua
    // a ser Amamentação / outro ecrã empilhado — parece que o botão Início “abre” outro sítio.
    _popTabToRoot(index);
    setState(() => selectedIndex = index);
    if (index == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollHomeToTop());
    }
  }

  void _scrollHomeToTop() {
    if (!_homeScrollController.hasClients) return;
    _homeScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  /// Voltar nativo Android: primeiro desempilha o [Navigator] do separador atual;
  /// se estiver na raiz e não for Início, vai para Início; na raiz do Início, envia a app para segundo plano.
  void _handleSystemBack() {
    final nav = ShellNestedNav.tabNavigatorKeys[selectedIndex].currentState;
    nav?.maybePop().then((didPopInner) {
      if (!mounted) return;
      if (didPopInner) return;
      if (selectedIndex != 0) {
        final resumeAt = _lastShellResumeAt;
        if (resumeAt != null &&
            DateTime.now().difference(resumeAt).inMilliseconds < 900) {
          // Evita saltar para Início quando o SO entrega um evento de voltar extra
          // ao fechar a galeria ou o seletor de ficheiros.
          return;
        }
        setState(() => selectedIndex = 0);
        for (var i = 0; i < 5; i++) {
          _popTabToRoot(i);
        }
        return;
      }
      SystemNavigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Envolver o AnimatedBuilder: senão `LoadingScope.of` apanha o scope do AppGate (árvore errada).
    final atNight = PortalTimeOfDay.isNight(DateTime.now());
    final bgAsset = PortalTimeOfDay.backgroundAsset(DateTime.now());
    final fallback =
        atNight ? const Color(0xFF152238) : const Color(0xFFB8D9EE);
    final veil =
        atNight ? Colors.white.withAlpha(55) : Colors.white.withAlpha(105);

    return LoadingScope(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          aiController,
          currentBaby,
          kAppLanguage,
          PremiumService.instance,
          PortalLayoutPrefs.instance,
          HomePrefs.aiMicEnabled,
          MeasurementUnitsPrefs.length,
          MeasurementUnitsPrefs.weight,
          MeasurementUnitsPrefs.liquid,
          MeasurementUnitsPrefs.temperature,
        ]),
        child: _StablePortalBackground(
          asset: bgAsset,
          fallback: fallback,
          veil: veil,
        ),
        builder: (context, stableBackground) {
          final s = S.of(context);
          final baby = _babyFromRow(currentBaby.currentBabyRow, s);
          final bg = AppTheme.backdropTintForSex(baby.sex);
          final motherName =
              (currentBaby.currentMotherRow?['name'] as String?)?.trim();
          final motherPhoto =
              currentBaby.currentMotherRow?['photo_b64'] as String?;
          final tabRoots = [
            HomePage(
              baby: baby,
              babyService: babyService,
              scrollController: _homeScrollController,
              onOpenQuickRegister: openQuickRegister,
              motherName: (motherName == null || motherName.isEmpty)
                  ? null
                  : motherName,
              motherPhotoB64: motherPhoto,
              onPickMotherPhoto: () async {
                final mid =
                    (currentBaby.currentMotherRow?['id'] as num?)?.toInt();
                if (mid == null) return;
                final b64 = await pickImageAsB64(
                    context: context, maxBytes: 2 * 1024 * 1024);
                if (!context.mounted || b64 == null) return;
                await LoadingScope.of(context).run(() async {
                  await AppDatabase.instance
                      .updateMotherPhoto(motherId: mid, photoB64: b64);
                  await currentBaby.refresh();
                  // Só conclui quando a foto estiver persistida na nuvem.
                  await ProfileCloudSync.pushMother(mid);
                }, label: s.loadingMotherPhoto);
              },
              onPickBabyPhoto: () async {
                final bid =
                    (currentBaby.currentBabyRow?['id'] as num?)?.toInt();
                if (bid == null) return;
                final b64 = await pickImageAsB64(
                    context: context, maxBytes: 2 * 1024 * 1024);
                if (!context.mounted || b64 == null) return;
                await LoadingScope.of(context).run(() async {
                  await AppDatabase.instance
                      .updateBabyPhoto(babyId: bid, photoB64: b64);
                  await currentBaby.refresh();
                  // Só conclui quando a foto estiver persistida na nuvem.
                  await ProfileCloudSync.pushBaby(bid);
                }, label: s.loadingBabyPhoto);
              },
              onPickBaby: () async {
                final babies = await LoadingScope.of(context).run(
                  () => currentBaby.listBabies(),
                  label: s.loadingBabies,
                );
                if (!context.mounted || babies.isEmpty) return;
                final picked = await showModalBottomSheet<int>(
                  context: context,
                  showDragHandle: true,
                  builder: (context) {
                    return SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          ListTile(
                            title: Text(s.pickBabyTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                          ),
                          ...babies.map((b) {
                            final id = (b['id'] as num).toInt();
                            final name = (b['name'] as String?) ?? '—';
                            final selected = currentBaby.currentBabyId == id;
                            return ListTile(
                              leading: const CircleAvatar(child: Text('👶')),
                              title: Text(name),
                              trailing: selected
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : null,
                              onTap: () => Navigator.of(context).pop(id),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                );
                if (!context.mounted) return;
                if (picked != null) {
                  await LoadingScope.of(context).run(
                    () => currentBaby.setCurrentBabyId(picked),
                    label: s.switchingBaby,
                  );
                }
              },
            ),
            const QuickRegisterPage(),
            const AiNannyScreen(),
            const new_memories.MemoriesPage(),
            const SettingsPage(),
          ];
          Widget tabNavigator(int i) {
            final key = ShellNestedNav.tabNavigatorKeys[i];
            return Theme(
              data: portalShellTheme(context),
              child: Navigator(
                key: key,
                observers: [
                  LoadingNavigatorObserver(key, maskTransitions: false),
                  _tabRouteObservers[i],
                ],
                initialRoute: '/',
                onGenerateRoute: (RouteSettings settings) {
                  if (settings.name == '/') {
                    return MaterialPageRoute<void>(
                      settings: settings,
                      builder: (_) => tabRoots[i],
                    );
                  }
                  return null;
                },
              ),
            );
          }

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              _handleSystemBack();
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: stableBackground!),
                Positioned.fill(
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: SafeArea(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: IndexedStack(
                            index: selectedIndex,
                            sizing: StackFit.expand,
                            children: [
                              tabNavigator(0),
                              tabNavigator(1),
                              tabNavigator(2),
                              tabNavigator(3),
                              tabNavigator(4),
                            ],
                          ),
                        ),
                      ),
                    ),
                    bottomNavigationBar: ValueListenableBuilder<int>(
                      valueListenable: _homeRouteDepth,
                      builder: (context, homeRouteDepth, _) {
                        final hideHomeActiveState =
                            selectedIndex == 0 && homeRouteDepth > 0;
                        return ShellBottomNavigation(
                          selectedIndex: selectedIndex,
                          onSelected: _onDestinationSelected,
                          aiLocked: !FeatureAccess.canUseAnyAi,
                          onAiTap: () {
                            if (!FeatureAccess.canUseAnyAi) {
                              openPremiumPaywall(context);
                              return;
                            }
                            _onDestinationSelected(2);
                          },
                          hideHomeActiveState: hideHomeActiveState,
                          navBarBackground:
                              AppTheme.navigationBarSurfaceForTint(bg),
                        );
                      },
                    ),
                  ),
                ),
                if (FeatureAccess.canUseAnyAi && aiController.isActive)
                  AiOverlay(
                    state: aiController.state,
                    onClose: aiController.close,
                  ),
                const WeeklyPhotoWinnerCongratsHost(),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: AppUpdateBanner(),
                  ),
                ),
                if (FeatureAccess.canUseAnyAi)
                  const Positioned.fill(child: AiNannyBubbleHost()),
              ],
            ),
          );
        },
      ),
    );
  }

  Baby _babyFromRow(Map<String, Object?>? row, S s) {
    if (row == null) {
      // Keep a safe placeholder; AppGate should prevent reaching here before first baby exists,
      // but we still avoid crashes.
      return Baby(
        name: s.placeholderBabyName,
        ageLabel: '—',
        avatar: '👶',
        weightKg: 0,
        heightCm: 0,
        birthDate: null,
      );
    }

    final name = (row['name'] as String?)?.trim();
    final sex =
        ((row['sex'] as String?)?.trim().toUpperCase() == 'M') ? 'M' : 'F';
    final birthRaw = row['birth_date'] as String?;
    DateTime? birthDate;
    if (birthRaw != null && birthRaw.isNotEmpty) {
      birthDate = DateTime.tryParse(birthRaw);
    }
    final age =
        birthDate == null ? '—' : s.babyAgeLabel(birthDate, DateTime.now());
    final weight = (row['weight_kg'] as num?)?.toDouble() ?? 0;
    final height = (row['height_cm'] as num?)?.toDouble() ?? 0;
    final photoB64 = row['photo_b64'] as String?;
    final pu = (row['photo_url'] as String?)?.trim();
    final photoUrl = (pu == null || pu.isEmpty) ? null : pu;

    return Baby(
      name: (name == null || name.isEmpty) ? s.placeholderBabyName : name,
      ageLabel: age,
      avatar: '👶',
      weightKg: weight,
      heightCm: height,
      sex: sex,
      photoB64: photoB64,
      photoUrl: photoUrl,
      birthDate: birthDate,
    );
  }
}

class _ShellTabRouteObserver extends NavigatorObserver {
  _ShellTabRouteObserver({
    required this.tabIndex,
    required this.onDepthChanged,
  });

  final int tabIndex;
  final void Function(int tabIndex, int depth) onDepthChanged;
  int _depth = 0;

  void _emit() {
    final depth = _depth;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onDepthChanged(tabIndex, depth);
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (!route.isFirst) _depth++;
    _emit();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (!route.isFirst && _depth > 0) _depth--;
    _emit();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (!route.isFirst && _depth > 0) _depth--;
    _emit();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _emit();
  }
}

class _StablePortalBackground extends StatefulWidget {
  const _StablePortalBackground({
    required this.asset,
    required this.fallback,
    required this.veil,
  });

  final String asset;
  final Color fallback;
  final Color veil;

  @override
  State<_StablePortalBackground> createState() =>
      _StablePortalBackgroundState();
}

class _StablePortalBackgroundState extends State<_StablePortalBackground> {
  late AssetImage _image;

  @override
  void initState() {
    super.initState();
    _image = AssetImage(widget.asset);
  }

  @override
  void didUpdateWidget(covariant _StablePortalBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _image = AssetImage(widget.asset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: widget.fallback),
        Image(
          image: _image,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => ColoredBox(color: widget.fallback),
        ),
        ColoredBox(color: widget.veil),
      ],
    );
  }
}
