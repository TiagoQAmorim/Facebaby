import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado visível do fluxo Play In-App Update (Android).
enum AppUpdateUiPhase {
  idle,
  /// Banner: nova versão disponível (flexível).
  updateAvailable,
  /// Download em segundo plano.
  downloading,
  /// Pronto para reiniciar e instalar.
  readyToInstall,
}

/// Política futura: versão mínima, changelog, update obrigatório via Play Console.
class UpdatePolicy {
  const UpdatePolicy({
    this.criticalPriorityThreshold = 4,
    this.checkInterval = const Duration(hours: 6),
    this.dismissSnooze = const Duration(hours: 24),
  });

  /// [updatePriority] do Play Developer API (0–5). ≥ limiar → immediate.
  final int criticalPriorityThreshold;
  final Duration checkInterval;
  final Duration dismissSnooze;
}

/// Google Play In-App Updates (oficial). Falhas são silenciosas — o app segue normal.
class UpdateService extends ChangeNotifier {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const _kLastCheckMs = 'play_update_last_check_ms';
  static const _kDismissedUntilMs = 'play_update_dismissed_until_ms';
  static const _kDismissedVersionCode = 'play_update_dismissed_version_code';

  final UpdatePolicy policy = const UpdatePolicy();

  AppUpdateUiPhase _phase = AppUpdateUiPhase.idle;
  AppUpdateInfo? _pendingInfo;
  PackageInfo? _packageInfo;
  StreamSubscription<InstallStatus>? _installSub;
  bool _checking = false;

  AppUpdateUiPhase get phase => _phase;
  AppUpdateInfo? get pendingInfo => _pendingInfo;
  String? get currentVersionLabel => _packageInfo?.version;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Chamar uma vez no boot (ex.: [main]).
  Future<void> initialize() async {
    if (!isSupported) return;
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {}
    await _installSub?.cancel();
    _installSub = InAppUpdate.installUpdateListener.listen(
      _onInstallStatus,
      onError: (_) {},
    );
  }

  void _onInstallStatus(InstallStatus status) {
    switch (status) {
      case InstallStatus.downloading:
      case InstallStatus.pending:
        if (_phase != AppUpdateUiPhase.readyToInstall) {
          _setPhase(AppUpdateUiPhase.downloading);
        }
        break;
      case InstallStatus.downloaded:
        _setPhase(AppUpdateUiPhase.readyToInstall);
        break;
      case InstallStatus.installed:
      case InstallStatus.canceled:
      case InstallStatus.failed:
        _resetToIdle();
        break;
      default:
        break;
    }
  }

  /// Verifica atualização se passou o intervalo e o utilizador não adiou.
  Future<void> checkForUpdateIfNeeded({bool force = false}) async {
    if (!isSupported || _checking) return;
    if (_phase == AppUpdateUiPhase.downloading ||
        _phase == AppUpdateUiPhase.readyToInstall) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    if (!force) {
      final lastMs = prefs.getInt(_kLastCheckMs);
      if (lastMs != null) {
        final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
        if (now.difference(last) < policy.checkInterval) return;
      }
    }

    _checking = true;
    try {
      await prefs.setInt(_kLastCheckMs, now.millisecondsSinceEpoch);

      final info = await InAppUpdate.checkForUpdate();
      _pendingInfo = info;

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        _resetToIdle();
        return;
      }

      final versionCode = info.availableVersionCode;
      final dismissed = _isDismissedForVersion(prefs, versionCode, now);
      final priority = info.updatePriority;
      final isCritical = priority >= policy.criticalPriorityThreshold;

      if (isCritical && info.immediateUpdateAllowed) {
        await _runImmediateUpdate();
        return;
      }

      if (info.flexibleUpdateAllowed && !dismissed) {
        _setPhase(AppUpdateUiPhase.updateAvailable);
        return;
      }

      _resetToIdle();
    } catch (_) {
      _resetToIdle();
    } finally {
      _checking = false;
    }
  }

  bool _isDismissedForVersion(
    SharedPreferences prefs,
    int? versionCode,
    DateTime now,
  ) {
    if (versionCode == null) return false;
    final dismissedCode = prefs.getInt(_kDismissedVersionCode);
    final untilMs = prefs.getInt(_kDismissedUntilMs);
    if (dismissedCode != versionCode || untilMs == null) return false;
    return now.isBefore(DateTime.fromMillisecondsSinceEpoch(untilMs));
  }

  /// Utilizador tocou em «Depois» — não voltar a mostrar esta versão por [policy.dismissSnooze].
  Future<void> dismissAvailableBanner() async {
    final code = _pendingInfo?.availableVersionCode;
    if (code == null) {
      _resetToIdle();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(policy.dismissSnooze);
    await prefs.setInt(_kDismissedVersionCode, code);
    await prefs.setInt(_kDismissedUntilMs, until.millisecondsSinceEpoch);
    _resetToIdle();
  }

  /// Inicia update flexível (background).
  Future<void> startFlexibleUpdate() async {
    if (!isSupported) return;
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success) {
        _setPhase(AppUpdateUiPhase.downloading);
      } else {
        if (_pendingInfo != null &&
            _pendingInfo!.updateAvailability ==
                UpdateAvailability.updateAvailable) {
          _setPhase(AppUpdateUiPhase.updateAvailable);
        } else {
          _resetToIdle();
        }
      }
    } catch (_) {
      if (_pendingInfo != null) {
        _setPhase(AppUpdateUiPhase.updateAvailable);
      } else {
        _resetToIdle();
      }
    }
  }

  /// Reinicia para aplicar update flexível já descarregado.
  Future<void> completeFlexibleUpdate() async {
    if (!isSupported) return;
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (_) {
      // Play pode pedir restart manual; app continua utilizável.
    }
  }

  /// Update crítico — ecrã completo até atualizar (Play API).
  Future<void> startImmediateUpdate() async {
    await _runImmediateUpdate();
  }

  Future<void> _runImmediateUpdate() async {
    if (!isSupported) return;
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (_) {
      // Utilizador cancelou ou Play indisponível — não bloquear o app.
      if (_pendingInfo?.flexibleUpdateAllowed == true) {
        _setPhase(AppUpdateUiPhase.updateAvailable);
      } else {
        _resetToIdle();
      }
    }
  }

  void _setPhase(AppUpdateUiPhase next) {
    if (_phase == next) return;
    _phase = next;
    notifyListeners();
  }

  void _resetToIdle() {
    if (_phase == AppUpdateUiPhase.idle) return;
    _phase = AppUpdateUiPhase.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _installSub?.cancel();
    super.dispose();
  }
}
