import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cronômetro de sono com pausa/cancelar; estado global até gravar ou abortar.
class SleepTimerController extends ChangeNotifier {
  SleepTimerController._();
  static final SleepTimerController instance = SleepTimerController._();

  static const _kBabyId = 'sleep_timer_baby_id';
  static const _kStartedAt = 'sleep_timer_started_at';
  static const _kPaused = 'sleep_timer_paused';
  static const _kPauseStartedAt = 'sleep_timer_pause_started_at';
  static const _kAccumPausedMs = 'sleep_timer_accum_paused_ms';

  Timer? _ticker;

  int? _babyId;
  DateTime? _startedAt;
  bool _paused = false;
  DateTime? _pauseStartedAt;
  Duration _accumulatedPaused = Duration.zero;

  int? get babyId => _babyId;
  DateTime? get startedAt => _startedAt;
  bool get isPaused => _paused;
  bool get isTracking => _startedAt != null && _babyId != null;

  bool _didInit = false;
  SharedPreferences? _prefs;

  Future<void> init() async {
    if (_didInit) return;
    _didInit = true;
    _prefs = await SharedPreferences.getInstance();
    try {
      final bid = _prefs!.getInt(_kBabyId);
      final startedIso = _prefs!.getString(_kStartedAt);
      final started = startedIso == null ? null : DateTime.tryParse(startedIso);
      if (bid != null && started != null) {
        _babyId = bid;
        _startedAt = started;
        _paused = _prefs!.getBool(_kPaused) ?? false;
        final pauseIso = _prefs!.getString(_kPauseStartedAt);
        _pauseStartedAt = pauseIso == null ? null : DateTime.tryParse(pauseIso);
        final accMs = _prefs!.getInt(_kAccumPausedMs) ?? 0;
        _accumulatedPaused = Duration(milliseconds: accMs.clamp(0, 1 << 30));
        _ensureTicker();
        notifyListeners();
      }
    } catch (_) {
      // ignore restore errors; treat as no active session
    }
  }

  Future<void> _persist() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (!isTracking) {
        await _prefs!.remove(_kBabyId);
        await _prefs!.remove(_kStartedAt);
        await _prefs!.remove(_kPaused);
        await _prefs!.remove(_kPauseStartedAt);
        await _prefs!.remove(_kAccumPausedMs);
        return;
      }
      await _prefs!.setInt(_kBabyId, _babyId!);
      await _prefs!.setString(_kStartedAt, _startedAt!.toIso8601String());
      await _prefs!.setBool(_kPaused, _paused);
      if (_pauseStartedAt != null) {
        await _prefs!.setString(_kPauseStartedAt, _pauseStartedAt!.toIso8601String());
      } else {
        await _prefs!.remove(_kPauseStartedAt);
      }
      await _prefs!.setInt(_kAccumPausedMs, _accumulatedPaused.inMilliseconds);
    } catch (_) {}
  }

  Duration get effectiveElapsed {
    if (_startedAt == null) return Duration.zero;
    var elapsed = DateTime.now().difference(_startedAt!);
    elapsed -= _accumulatedPaused;
    if (_paused && _pauseStartedAt != null) {
      elapsed -= DateTime.now().difference(_pauseStartedAt!);
    }
    if (elapsed.isNegative) return Duration.zero;
    return elapsed;
  }

  void _ensureTicker() {
    _ticker?.cancel();
    if (!isTracking) {
      _ticker = null;
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
  }

  void begin({required int babyId}) {
    if (isTracking) return;
    _babyId = babyId;
    _startedAt = DateTime.now();
    _paused = false;
    _pauseStartedAt = null;
    _accumulatedPaused = Duration.zero;
    _ensureTicker();
    // fire-and-forget persistence
    unawaited(_persist());
    notifyListeners();
  }

  void pause() {
    if (!isTracking || _paused) return;
    _paused = true;
    _pauseStartedAt = DateTime.now();
    unawaited(_persist());
    notifyListeners();
  }

  void resume() {
    if (!_paused || _pauseStartedAt == null) return;
    _accumulatedPaused += DateTime.now().difference(_pauseStartedAt!);
    _paused = false;
    _pauseStartedAt = null;
    unawaited(_persist());
    notifyListeners();
  }

  /// Descarta sessão sem gravar (ex.: troca de bebê).
  void discardIfBabyMismatch(int? currentBabyId) {
    if (!isTracking) return;
    if (currentBabyId == null || _babyId != currentBabyId) {
      clearSession();
    }
  }

  void clearSession() {
    _ticker?.cancel();
    _ticker = null;
    _babyId = null;
    _startedAt = null;
    _paused = false;
    _pauseStartedAt = null;
    _accumulatedPaused = Duration.zero;
    unawaited(_persist());
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
