import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'premium/feature_access.dart';

/// Indica na guia Horóscopo que o texto do dia ainda não foi aberto.
abstract final class FamilyHoroscopeUnreadBadge {
  FamilyHoroscopeUnreadBadge._();

  static final ValueNotifier<bool> show = ValueNotifier<bool>(false);

  static Future<void> refresh() async {
    if (!FeatureAccess.canUseAiFamilyHoroscope) {
      show.value = false;
      return;
    }
    show.value = !(await FamilyHoroscopeReadPrefs.isTodayRead());
  }
}

/// Data (yyyyMMdd) em que a mãe abriu a guia Horóscopo pela última vez.
abstract final class FamilyHoroscopeReadPrefs {
  FamilyHoroscopeReadPrefs._();

  static const _readDateKey = 'facebaby_family_horoscope_read_date_v1';

  static String _todayKey() => DateFormat('yyyyMMdd').format(DateTime.now());

  static Future<bool> isTodayRead() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_readDateKey) == _todayKey();
  }

  static Future<void> markTodayRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_readDateKey, _todayKey());
    await FamilyHoroscopeUnreadBadge.refresh();
  }

  /// Novo dia civil: volta a mostrar «!» até abrir a guia.
  static Future<void> clearIfNewDay() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_readDateKey);
    final today = _todayKey();
    if (stored != null && stored != today) {
      await FamilyHoroscopeUnreadBadge.refresh();
    }
  }
}
