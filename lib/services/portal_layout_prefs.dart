import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferência de layout do portal (reutiliza o mesmo dia/noite do automático).
enum PortalLayoutMode {
  automatic,
  day,
  night,
}

class PortalLayoutPrefs extends ChangeNotifier {
  PortalLayoutPrefs._();

  static const _storageKey = 'facebaby_portal_layout_mode_v1';
  static final PortalLayoutPrefs instance = PortalLayoutPrefs._();

  PortalLayoutMode _mode = PortalLayoutMode.automatic;

  PortalLayoutMode get mode => _mode;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    instance._mode = _parseMode(raw);
  }

  static PortalLayoutMode _parseMode(String? raw) {
    for (final m in PortalLayoutMode.values) {
      if (m.name == raw) return m;
    }
    return PortalLayoutMode.automatic;
  }

  /// Mesma regra do portal: 18:30–06:00.
  static bool isNightByClock(DateTime at) {
    final h = at.hour;
    return h < 6 || h > 18 || (h == 18 && at.minute >= 30);
  }

  bool resolveIsNight(DateTime at) {
    switch (_mode) {
      case PortalLayoutMode.day:
        return false;
      case PortalLayoutMode.night:
        return true;
      case PortalLayoutMode.automatic:
        return isNightByClock(at);
    }
  }

  Future<void> setMode(PortalLayoutMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, mode.name);
  }
}
