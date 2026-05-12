import 'dart:async' show unawaited;

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
import '../pages/memories/memories_page.dart' as new_memories;
import '../services/mock_baby_service.dart';
import '../utils/pick_image_b64.dart';
import '../services/app_database.dart';
import '../services/home_prefs.dart';
import '../services/local_notifications_service.dart';
import '../services/reminder_monitor.dart';
import '../services/firebase/profile_cloud_sync.dart';
import '../services/measurement_units_prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_button.dart';
import '../widgets/ai_overlay.dart';
import '../widgets/loading_scope.dart';
import '../widgets/loading_navigator_observer.dart';
import '../widgets/weekly_photo_winner_congrats_host.dart';
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
  late final VoidCallback _aiMicListener;

  /// Usado para ignorar um “back” fantasma logo após voltar da galeria / file picker (Android).
  DateTime? _lastShellResumeAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocalNotificationsService.instance.requestPermissionOnceOnFirstLaunch();
    });
    unawaited(_bootstrapRemindersPipeline());
    _aiMicListener = () {
      if (!HomePrefs.aiMicEnabled.value && aiController.isActive) {
        aiController.close();
      }
    };
    HomePrefs.aiMicEnabled.addListener(_aiMicListener);
    ShellNestedNav.selectTab = _goToTab;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastShellResumeAt = DateTime.now();
      // Após segundo plano: re-sincroniza bebé/mãe na BD (evita UI “sem cadastro” por estado stale).
      unawaited(currentBaby.refresh());
      // Reagenda lembretes locais (não depender só da Home puxada para refresh).
      ReminderMonitor.instance.onAppResumed();
    }
  }

  /// Garante bebé + prefs carregados antes de [ReminderMonitor] — evita o primeiro [sync] com
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
    if (!mounted) return;
    ReminderMonitor.instance.start();
  }

  void _goToTab(int index) {
    if (!mounted) return;
    setState(() {
      selectedIndex = index.clamp(0, 3);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ShellNestedNav.selectTab = null;
    HomePrefs.aiMicEnabled.removeListener(_aiMicListener);
    aiController.dispose();
    ReminderMonitor.instance.stop();
    super.dispose();
  }

  void _popRecordsTabToRoot() {
    _popTabToRoot(_recordsTabIndex);
  }

  /// Volta à raiz do separador (única rota `'/'`), para o ícone do nav corresponder ao ecrã visível.
  void _popTabToRoot(int tabIndex) {
    ShellNestedNav.tabNavigatorKeys[tabIndex].currentState?.popUntil((route) => route.isFirst);
  }

  void openQuickRegister() {
    _popRecordsTabToRoot();
    setState(() => selectedIndex = _recordsTabIndex);
  }

  void _onDestinationSelected(int index) {
    // Sem isto, ao voltar ao Início o [selectedIndex] pode ser 0 mas o topo da pilha continua
    // a ser Amamentação / outro ecrã empilhado — parece que o botão Início “abre” outro sítio.
    _popTabToRoot(index);
    setState(() => selectedIndex = index);
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
        if (resumeAt != null && DateTime.now().difference(resumeAt).inMilliseconds < 900) {
          // Evita saltar para Início quando o SO entrega um evento de voltar extra
          // ao fechar a galeria ou o seletor de ficheiros.
          return;
        }
        setState(() => selectedIndex = 0);
        for (var i = 0; i < 4; i++) {
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
    return LoadingScope(
      child: AnimatedBuilder(
      animation: Listenable.merge([
        aiController,
        currentBaby,
        kAppLanguage,
        HomePrefs.aiMicEnabled,
        MeasurementUnitsPrefs.length,
        MeasurementUnitsPrefs.weight,
        MeasurementUnitsPrefs.liquid,
        MeasurementUnitsPrefs.temperature,
      ]),
      builder: (context, _) {
        final s = S.of(context);
        final baby = _babyFromRow(currentBaby.currentBabyRow, s);
        final bg = AppTheme.backdropTintForSex(baby.sex);
        final motherName = (currentBaby.currentMotherRow?['name'] as String?)?.trim();
        final motherPhoto = currentBaby.currentMotherRow?['photo_b64'] as String?;
        final tabRoots = [
          HomePage(
            baby: baby,
            babyService: babyService,
            onOpenQuickRegister: openQuickRegister,
            motherName: (motherName == null || motherName.isEmpty) ? null : motherName,
            motherPhotoB64: motherPhoto,
            onPickMotherPhoto: () async {
              final mid = (currentBaby.currentMotherRow?['id'] as num?)?.toInt();
              if (mid == null) return;
              final b64 = await pickImageAsB64(context: context, maxBytes: 2 * 1024 * 1024);
              if (!context.mounted || b64 == null) return;
              await LoadingScope.of(context).run(() async {
                await AppDatabase.instance.updateMotherPhoto(motherId: mid, photoB64: b64);
                await currentBaby.refresh();
                // Só conclui quando a foto estiver persistida na nuvem.
                await ProfileCloudSync.pushMother(mid);
              }, label: s.loadingMotherPhoto);
            },
            onPickBabyPhoto: () async {
              final bid = (currentBaby.currentBabyRow?['id'] as num?)?.toInt();
              if (bid == null) return;
              final b64 = await pickImageAsB64(context: context, maxBytes: 2 * 1024 * 1024);
              if (!context.mounted || b64 == null) return;
              await LoadingScope.of(context).run(() async {
                await AppDatabase.instance.updateBabyPhoto(babyId: bid, photoB64: b64);
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
                          title: Text(s.pickBabyTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                        ...babies.map((b) {
                          final id = (b['id'] as num).toInt();
                          final name = (b['name'] as String?) ?? '—';
                          final selected = currentBaby.currentBabyId == id;
                          return ListTile(
                            leading: const CircleAvatar(child: Text('👶')),
                            title: Text(name),
                            trailing: selected ? const Icon(Icons.check, color: Colors.green) : null,
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
          const new_memories.MemoriesPage(),
          const SettingsPage(),
        ];
        Widget tabNavigator(int i) {
          final key = ShellNestedNav.tabNavigatorKeys[i];
          return Navigator(
            key: key,
            observers: [LoadingNavigatorObserver(key)],
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
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.lerp(const Color(0xFFFAFBFE), bg, 0.08)!,
                  ),
                ),
              ),
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
                          ],
                        ),
                      ),
                    ),
                  ),
                  bottomNavigationBar: SafeArea(
                    top: false,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        navigationBarTheme: Theme.of(context).navigationBarTheme.copyWith(
                          backgroundColor: AppTheme.navigationBarSurfaceForTint(bg),
                        ),
                      ),
                      child: NavigationBar(
                        selectedIndex: selectedIndex,
                        onDestinationSelected: _onDestinationSelected,
                        destinations: [
                          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: s.home),
                          NavigationDestination(
                            icon: const Icon(Icons.edit_note_outlined),
                            selectedIcon: const Icon(Icons.edit_note),
                            label: s.records,
                          ),
                          NavigationDestination(icon: const Icon(Icons.favorite_border), selectedIcon: const Icon(Icons.favorite), label: s.memories),
                          NavigationDestination(icon: const Icon(Icons.menu), label: s.more),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (HomePrefs.aiMicEnabled.value)
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 72,
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AiButton(state: aiController.state, onTap: aiController.toggle),
                    ),
                  ),
                ),
              if (aiController.isActive)
                AiOverlay(
                  state: aiController.state,
                  onClose: aiController.close,
                ),
              const WeeklyPhotoWinnerCongratsHost(),
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
    final sex = ((row['sex'] as String?)?.trim().toUpperCase() == 'M') ? 'M' : 'F';
    final birthRaw = row['birth_date'] as String?;
    DateTime? birthDate;
    if (birthRaw != null && birthRaw.isNotEmpty) {
      birthDate = DateTime.tryParse(birthRaw);
    }
    final age = birthDate == null ? '—' : s.babyAgeLabel(birthDate, DateTime.now());
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
