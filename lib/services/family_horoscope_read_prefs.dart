import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai/family_horoscope_service.dart';
import 'premium/feature_access.dart';

/// Indica na guia Horóscopo que o horóscopo do dia existe e ainda não foi lido.
abstract final class FamilyHoroscopeUnreadBadge {
  FamilyHoroscopeUnreadBadge._();

  static final ValueNotifier<bool> show = ValueNotifier<bool>(false);

  static Future<void> refresh() async {
    if (!FeatureAccess.canUseAiFamilyHoroscope) {
      show.value = false;
      return;
    }
    final read = await FamilyHoroscopeReadPrefs.isTodayRead();
    final cached = await FamilyHoroscopeService().loadTodayCached();
    final ready = cached != null && cached.motherText.trim().isNotEmpty;
    show.value = ready && !read;
    if (ready && !read) {
      await FamilyHoroscopeBubbleAlert.onHoroscopeReady();
    }
  }
}

/// Aviso no balão da IA Babá quando o horóscopo do dia está pronto.
abstract final class FamilyHoroscopeBubbleAlert {
  FamilyHoroscopeBubbleAlert._();

  static const _dismissKey = 'facebaby_family_horoscope_bubble_dismiss_v1';

  static String _todayKey() => DateFormat('yyyyMMdd').format(DateTime.now());

  static Future<void> onHoroscopeReady() async {
    if (!FeatureAccess.canUseAiFamilyHoroscope) return;
    if (await FamilyHoroscopeReadPrefs.isTodayRead()) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_dismissKey) == _todayKey()) return;
    FamilyHoroscopeReadyNotifier.tick();
  }

  static Future<bool> shouldShowInBubble() async {
    if (!FeatureAccess.canUseAiFamilyHoroscope) return false;
    if (await FamilyHoroscopeReadPrefs.isTodayRead()) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_dismissKey) == _todayKey()) return false;
    final cached = await FamilyHoroscopeService().loadTodayCached();
    return cached != null && cached.motherText.trim().isNotEmpty;
  }

  static Future<void> dismissForToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissKey, _todayKey());
    FamilyHoroscopeReadyNotifier.tick();
  }
}

/// Sinaliza hosts (balão IA) para reconstruir a fila de mensagens.
abstract final class FamilyHoroscopeReadyNotifier {
  FamilyHoroscopeReadyNotifier._();

  static final ValueNotifier<int> generation = ValueNotifier<int>(0);

  static void tick() => generation.value++;
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
