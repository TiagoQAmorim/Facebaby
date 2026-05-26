import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'breastfeeding_timer_controller.dart';
import 'sleep_timer_controller.dart';
import '../services/app_database.dart';
import '../services/firebase/cloud_bootstrap_sync.dart';
import '../services/firebase/firestore_user_repository.dart';
import '../services/firebase/cloud_load_status.dart';

class CurrentBabyController extends ChangeNotifier {
  static final CurrentBabyController instance = CurrentBabyController._();
  CurrentBabyController._();

  static const _prefsKey = 'current_baby_id';
  static const int _maxEmptyGraceRefreshAttempts = 8;
  static const int _maxStaleFallbackRecoveries = 6;

  int? _currentBabyId;
  SharedPreferences? _prefs;
  List<Map<String, Object?>> _babies = const [];
  Map<String, Object?>? _currentBabyRow;
  Map<String, Object?>? _currentMotherRow;
  /// Último par válido na UI — evita voltar a «Mamãe / Bebê» por leitura vazia transitória.
  Map<String, Object?>? _fallbackBabyRow;
  Map<String, Object?>? _fallbackMotherRow;
  int _emptyGraceAttempt = 0;
  int _staleFallbackRecoveries = 0;

  int? get currentBabyId => _currentBabyId;
  /// Firestore `users/{uid}/babies/{id}` — usado por Cloud Functions de IA.
  String? get currentBabyCloudId {
    final id = (_currentBabyRow?['cloud_id'] as String?)?.trim();
    return (id == null || id.isEmpty) ? null : id;
  }

  List<Map<String, Object?>> get babies => _babies;
  Map<String, Object?>? get currentBabyRow => _currentBabyRow;
  Map<String, Object?>? get currentMotherRow => _currentMotherRow;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _currentBabyId = _prefs!.getInt(_prefsKey);
    debugPrint('CurrentBaby.init current_baby_id=$_currentBabyId');
    await refresh();
    // Se por qualquer motivo o SQLite vier vazio (reset/restart/bug), re-hidrata da nuvem (Firestore)
    // e tenta novamente. Isso evita “sumiu o bebê / memórias” após alguns minutos.
    if (_babies.isEmpty) {
      await CloudBootstrapSync.hydrateProfilesIfMissing();
      await refresh();
    }
    // Modelo robusto: se ainda estiver vazio, tenta recuperar a partir do gate (users/{uid}.selectedBabyId)
    if (_babies.isEmpty) {
      await _recoverFromCloudSelectedIfPossible();
      await refresh();
    }
  }

  Future<void> setCurrentBabyId(int id) async {
    _prefs ??= await SharedPreferences.getInstance();
    _currentBabyId = id;
    debugPrint('CurrentBaby.set current_baby_id=$id');
    await _prefs!.setInt(_prefsKey, id);
    await refresh();
    SleepTimerController.instance.discardIfBabyMismatch(id);
    BreastfeedingTimerController.instance.discardIfBabyMismatch(id);
    await _mirrorSelectedBabyToCloud(id);
  }

  /// Mantém `users/{uid}.selectedBabyId` alinhado ao bebé activo (outros ecrãs / dispositivos).
  Future<void> _mirrorSelectedBabyToCloud(int localBabyId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final row = await AppDatabase.instance.getBabyById(localBabyId);
      final cloudId = (row?['cloud_id'] as String?)?.trim();
      if (cloudId == null || cloudId.isEmpty) return;
      await FirestoreUserRepository.instance
          .setSelectedBabyId(user.uid, cloudId);
    } catch (e, st) {
      debugPrint('CurrentBaby._mirrorSelectedBabyToCloud: $e\n$st');
    }
  }

  Future<List<Map<String, Object?>>> listBabies() async {
    return AppDatabase.instance.listBabies();
  }

  Future<Map<String, Object?>?> _loadBabyByIdWithRetries(int id) async {
    Map<String, Object?>? row;
    for (var i = 0; i < 10; i++) {
      row = await AppDatabase.instance.getBabyById(id);
      if (row != null) return row;
      await Future<void>.delayed(Duration(milliseconds: 60 + i * 110));
    }
    return null;
  }

  void _rememberSnapshot() {
    final b = _currentBabyRow;
    final m = _currentMotherRow;
    if (b != null) {
      _fallbackBabyRow = Map<String, Object?>.from(b);
    }
    if (m != null) {
      _fallbackMotherRow = Map<String, Object?>.from(m);
    }
  }

  Future<void> refresh() async {
    try {
      var babies = await listBabies();
      // Várias tentativas (como o AppGate): leitura vazia por corrida / BD ocupada ao voltar do 2.º plano.
      for (var attempt = 0; attempt < 8; attempt++) {
        if (babies.isNotEmpty) break;
        await Future<void>.delayed(Duration(milliseconds: 50 + attempt * 95));
        babies = await listBabies();
      }
      // Lista vazia mas há id gravado: último recurso — evita «cadastre um bebê» fantasma na UI.
      if (babies.isEmpty && _currentBabyId != null) {
        final row = await _loadBabyByIdWithRetries(_currentBabyId!);
        if (row != null) {
          babies = [row];
        }
      }
      await _applyBabies(babies);
    } catch (_) {
      // Evita “sumiu o bebê” na UI se a leitura falhar uma vez (rede/web/prefs) mas já tínhamos dados.
      if (_babies.isEmpty) rethrow;
      notifyListeners();
    }
  }

  Future<void> _recoverFromCloudSelectedIfPossible() async {
    try {
      final gate = await FirestoreUserRepository.instance.loadGate();
      final selectedCloud = gate.selectedBabyId?.trim();
      if (gate.status != CloudLoadStatus.loaded || selectedCloud == null || selectedCloud.isEmpty) return;
      final localId = await CloudBootstrapSync.ensureSelectedBabyCached(selectedBabyCloudId: selectedCloud);
      if (localId != null) {
        await setCurrentBabyId(localId);
      }
    } catch (e) {
      debugPrint('CurrentBaby.recoverFromCloudSelected failed: $e');
    }
  }

  Future<void> _applyBabies(List<Map<String, Object?>> babies) async {
    if (babies.isEmpty && _currentBabyId != null && (_babies.isNotEmpty || _currentBabyRow != null)) {
      final row = await _loadBabyByIdWithRetries(_currentBabyId!);
      if (row != null) {
        await _applyBabies([row]);
        return;
      }
    }
    if (babies.isEmpty) {
      // Grace period: DB pode responder vazio por corrida / lock (especialmente após voltar do 2º plano).
      // Não apague o "current_baby_id". E tente recuperar automaticamente mesmo se o estado atual já está vazio:
      // às vezes a primeira leitura vem vazia e só na próxima tentativa a BD responde (caso "sumiu do nada").
      if (_emptyGraceAttempt < _maxEmptyGraceRefreshAttempts) {
        _emptyGraceAttempt++;
        // Se já tínhamos dados, mantém UI; se não tínhamos, continua vazio mas tentará recuperar já já.
        notifyListeners();
        Future<void>.delayed(Duration(milliseconds: 260 + 220 * _emptyGraceAttempt), refresh);
        return;
      }
      _emptyGraceAttempt = 0;

      // Modelo robusto: antes de "zerar" a UI, tenta recuperar do bebê selecionado na nuvem.
      await _recoverFromCloudSelectedIfPossible();
      final after = await listBabies().catchError((_) => <Map<String, Object?>>[]);
      if (after.isNotEmpty) {
        await _applyBabies(after);
        return;
      }

      if (_currentBabyId != null) {
        final row = await _loadBabyByIdWithRetries(_currentBabyId!);
        if (row != null) {
          await _applyBabies([row]);
          return;
        }
      }

      if (_currentBabyId != null) {
        final fbId = (_fallbackBabyRow?['id'] as num?)?.toInt();
        if (_fallbackBabyRow != null &&
            fbId == _currentBabyId &&
            _staleFallbackRecoveries < _maxStaleFallbackRecoveries) {
          _staleFallbackRecoveries++;
          _babies = [_fallbackBabyRow!];
          _currentBabyRow = _fallbackBabyRow;
          _currentMotherRow = _fallbackMotherRow;
          notifyListeners();
          Future<void>.delayed(const Duration(milliseconds: 900), refresh);
          return;
        }
      }

      _staleFallbackRecoveries = 0;
      _fallbackBabyRow = null;
      _fallbackMotherRow = null;
      _babies = const [];
      _currentBabyRow = null;
      _currentMotherRow = null;
      notifyListeners();
      return;
    }

    _emptyGraceAttempt = 0;
    _staleFallbackRecoveries = 0;
    var rows = babies;
    if (!kIsWeb) {
      final repaired = await CloudBootstrapSync.repairOrphanMotherLinks();
      if (repaired) {
        final fresh = await listBabies();
        if (fresh.isEmpty) {
          await _applyBabies(fresh);
          return;
        }
        rows = fresh;
      }
    }
    _babies = rows;
    final desiredId = _currentBabyId;
    final fallbackId = (rows.first['id'] as num?)?.toInt();
    final resolvedId = desiredId ?? fallbackId;

    _currentBabyRow = resolvedId == null
        ? rows.first
        : rows.firstWhere(
            (b) => (b['id'] as num?)?.toInt() == resolvedId,
            orElse: () => rows.first,
          );

    // Se não há id selecionado (ou veio inválido), auto-seleciona o 1º bebê e persiste no prefs.
    // Sem isso, telas que checam `currentBabyId == null` exibem "cadastre um bebê" mesmo com dados no BD.
    final pickedId = (_currentBabyRow?['id'] as num?)?.toInt();
    if (pickedId != null && pickedId != _currentBabyId) {
      _prefs ??= await SharedPreferences.getInstance();
      _currentBabyId = pickedId;
      await _prefs!.setInt(_prefsKey, pickedId);
    }

    final mid = (_currentBabyRow?['mother_id'] as num?)?.toInt();
    _currentMotherRow = mid == null ? null : await AppDatabase.instance.getMotherById(mid);

    _rememberSnapshot();
    notifyListeners();

    if (pickedId != null) {
      // Puxa conteúdo do bebê (consultas, vacinas, memórias) em background.
      CloudBootstrapSync.hydrateBabyContentSoon(pickedId);
    }
  }
}
