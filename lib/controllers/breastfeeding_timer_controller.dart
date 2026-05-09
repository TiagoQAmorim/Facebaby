import 'dart:async';

import 'package:flutter/foundation.dart';

/// Cronômetro de amamentação (E/D) que **permanece ativo** ao sair da tela até a mãe finalizar ou trocar bebê.
class BreastfeedingTimerController extends ChangeNotifier {
  BreastfeedingTimerController._();
  static final BreastfeedingTimerController instance = BreastfeedingTimerController._();

  Timer? _ticker;

  int? _babyId;
  String? _side;
  DateTime? _startedAt;

  int? get babyId => _babyId;
  String? get side => _side;
  DateTime? get startedAt => _startedAt;

  bool get isRunning => _side != null && _startedAt != null && _babyId != null;

  Duration elapsedForSide(String breastSide) {
    if (_side != breastSide || _startedAt == null) return Duration.zero;
    return DateTime.now().difference(_startedAt!);
  }

  void _startTickerIfNeeded() {
    _ticker?.cancel();
    if (!isRunning) {
      _ticker = null;
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
  }

  /// Esquecer sessão (ex.: troca de bebê com sessão pendente para outro id).
  void clearSession({bool silent = false}) {
    _ticker?.cancel();
    _ticker = null;
    _babyId = null;
    _side = null;
    _startedAt = null;
    if (!silent) notifyListeners();
  }

  /// Ajustar bebê corrente: se há sessão de outro bebê, descarta só o estado local sem salvar.
  void discardIfBabyMismatch(int? currentBabyId) {
    if (!isRunning) return;
    if (currentBabyId == null || _babyId != currentBabyId) {
      clearSession();
    }
  }

  Future<void> onCircleTap({
    required int babyId,
    required String tappedSide,
    required Future<void> Function({required DateTime start, required DateTime end, required String side}) persistBreast,
    required VoidCallback snackbarTooShort,
  }) async {
    final now = DateTime.now();
    final curSide = _side;
    final curStart = _startedAt;

    if (curSide == tappedSide) {
      if (curStart != null) {
        final sec = now.difference(curStart).inSeconds;
        if (sec < 5) {
          snackbarTooShort();
        } else {
          await persistBreast(start: curStart, end: now, side: tappedSide);
        }
      }
      _clearLocalStateKeepListeners();
      return;
    }

    if (curSide != null && curStart != null && _babyId == babyId) {
      await persistBreast(start: curStart, end: now, side: curSide);
    }

    _babyId = babyId;
    _side = tappedSide;
    _startedAt = now;
    _startTickerIfNeeded();
    notifyListeners();
  }

  void _clearLocalStateKeepListeners() {
    _ticker?.cancel();
    _ticker = null;
    _side = null;
    _startedAt = null;
    _babyId = null;
    notifyListeners();
  }
}
