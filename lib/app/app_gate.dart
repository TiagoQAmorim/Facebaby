import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../controllers/current_baby_controller.dart';
import '../services/firebase/cloud_bootstrap_sync.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/cloud_load_status.dart';
import '../services/firebase/firestore_user_repository.dart';
import '../pages/auth/onboarding_page.dart';
import 'main_shell.dart';
import '../widgets/face_baby_loading.dart';
import '../widgets/loading_scope.dart';
import '../services/app_database.dart';
import '../services/firebase/profile_cloud_sync.dart';
import '../services/onboarding_draft_store.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  late Future<CloudLoadResult> _gateFuture;
  Future<void>? _cacheFuture;

  /// Último resultado conhecido do portão (evita flicker em resume).
  /// substituir o [Future] do [FutureBuilder] ao voltar da galeria/seletor de ficheiros:
  /// um novo `Future` faz o builder entrar em `waiting`, remove o [MainShell] da árvore
  /// e perde-se o separador ativo (parece “voltar ao Início”) sem upload concluído.
  CloudLoadResult? _lastGate;

  Future<CloudLoadResult> _trackGateFuture(Future<CloudLoadResult> inner) {
    return inner.then((r) {
      _lastGate = r;
      return r;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gateFuture = _trackGateFuture(_loadGateWithPendingOnboarding());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Após voltar do segundo plano, volta a ler a BD sem ecrã de loading infinito.
    unawaited(_revalidateAfterResume());
  }

  Future<void> _revalidateAfterResume() async {
    // Evita “apagou tudo” em resume: revalida nuvem, mas não manda automaticamente pro cadastro em erro.
    try {
      await CurrentBabyController.instance.refresh();
    } catch (_) {}
    if (!mounted) return;

    // Se já estávamos em loaded, não recalculamos agressivamente em resume.
    if (_lastGate?.status == CloudLoadStatus.loaded) return;

    try {
      final r = await _loadGateWithPendingOnboarding();
      if (!mounted) return;
      setState(() => _gateFuture = Future.value(r));
    } catch (_) {}
  }

  void _refresh() {
    setState(() {
      _cacheFuture = null;
      _gateFuture = _trackGateFuture(_loadGateWithPendingOnboarding());
    });
  }

  Future<CloudLoadResult> _loadGateWithPendingOnboarding() async {
    final initial = await FirestoreUserRepository.instance.loadGate();
    if (initial.status == CloudLoadStatus.loaded) return initial;
    if (initial.status != CloudLoadStatus.newUser &&
        initial.status != CloudLoadStatus.missingBaby) {
      return initial;
    }

    final draft = await OnboardingDraftStore.load();
    final localBabyId = draft.localBabyId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (localBabyId == null || uid == null) return initial;

    try {
      await ProfileCloudSync.pushBaby(localBabyId);
      final baby = await AppDatabase.instance.getBabyById(localBabyId);
      final cloudId = (baby?['cloud_id'] as String?)?.trim();
      if (cloudId != null && cloudId.isNotEmpty) {
        await FirestoreUserRepository.instance.saveUserProfile(uid, {
          'name': FirebaseAuth.instance.currentUser?.displayName,
          'email': FirebaseAuth.instance.currentUser?.email,
        });
        await FirestoreUserRepository.instance.setSelectedBabyId(uid, cloudId);
        await OnboardingDraftStore.clear();
        return await FirestoreUserRepository.instance.loadGate();
      }
    } catch (e, st) {
      debugPrint('AppGate.pendingOnboardingSync failed: $e\n$st');
    }
    return initial;
  }

  Future<void> _ensureCacheReady(String selectedBabyId) async {
    try {
      // Ensure local mother/baby exists even if prefs/SQLite got stale.
      final localId = await CloudBootstrapSync.ensureSelectedBabyCached(
          selectedBabyCloudId: selectedBabyId);
      if (localId != null) {
        await CurrentBabyController.instance.setCurrentBabyId(localId);
      }
      // Hydrate baby content in background (events -> sqlite)
      if (localId != null) {
        CloudBootstrapSync.hydrateBabyContentSoon(localId);
      }
    } catch (e) {
      debugPrint('AppGate.ensureCacheReady failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CloudLoadResult>(
      future: _gateFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: FaceBabySpinner(size: 36, strokeWidth: 3.5),
            ),
          );
        }
        final r = snap.data ??
            const CloudLoadResult(status: CloudLoadStatus.unknownError);

        // Segurança: AuthGate deve segurar, mas mantemos o estado.
        if (FirebaseAuth.instance.currentUser == null ||
            r.status == CloudLoadStatus.unauthenticated) {
          return const Scaffold(
              body: Center(child: FaceBabySpinner(size: 36, strokeWidth: 3.5)));
        }

        if (r.status == CloudLoadStatus.permissionDenied ||
            r.status == CloudLoadStatus.networkError ||
            r.status == CloudLoadStatus.unknownError) {
          final theme = Theme.of(context);
          final code = r.errorCode ??
              (r.error is FirebaseException
                  ? (r.error as FirebaseException).code
                  : null);
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: 52, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    const Text(
                      'Não foi possível acessar seus dados na nuvem.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Para manter seus dados seguros, é obrigatório carregar a nuvem para continuar.\n'
                      'Verifique sua conexão e tente novamente.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    if (code != null)
                      Text(
                        'Erro: $code',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed: _refresh,
                        child: const Text('Tentar novamente')),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () async {
                        await AuthService.instance.signOut();
                      },
                      child: const Text('Sair da conta'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (r.status == CloudLoadStatus.newUser) {
          return LoadingScope(
            child: OnboardingPage(
              requireProfileOnly: true,
              onCompleted: _refresh,
            ),
          );
        }

        if (r.status == CloudLoadStatus.missingBaby) {
          return LoadingScope(
            child: OnboardingPage(
              requireProfileOnly: true,
              onCompleted: _refresh,
            ),
          );
        }

        // Loaded: opcionalmente hidrata cache local (enquanto a Home ainda usa SQLite).
        final uid = r.uid;
        final selectedCloud = r.selectedBabyId;
        if (uid != null &&
            selectedCloud != null &&
            selectedCloud.trim().isNotEmpty) {
          _cacheFuture ??= _ensureCacheReady(selectedCloud);
          return FutureBuilder<void>(
            future: _cacheFuture,
            builder: (context, cacheSnap) {
              if (cacheSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                      child: FaceBabySpinner(size: 36, strokeWidth: 3.5)),
                );
              }
              unawaited(CloudBootstrapSync.hydrateProfilesIfMissing());
              return const MainShell();
            },
          );
        }
        unawaited(CloudBootstrapSync.hydrateProfilesIfMissing());
        return const MainShell();
      },
    );
  }
}
