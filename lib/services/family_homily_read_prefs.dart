import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/family_date_keys.dart';
import 'ai/family_homily_service.dart';
import 'premium/feature_access.dart';

/// «!» na guia Homilia quando a homilia do dia existe e ainda não foi lida.
abstract final class FamilyHomilyUnreadBadge {
  FamilyHomilyUnreadBadge._();

  static final ValueNotifier<bool> show = ValueNotifier<bool>(false);

  static Future<void> refresh() async {
    if (!FeatureAccess.canUseAiFamilyHomily) {
      show.value = false;
      return;
    }
    final read = await FamilyHomilyReadPrefs.isTodayRead();
    final cached = await FamilyHomilyService().loadTodayCached();
    final ready = cached != null && cached.homilyText.trim().isNotEmpty;
    show.value = ready && !read;
    if (ready && !read) {
      await FamilyHomilyBubbleAlert.onHomilyReady();
    }
  }
}

abstract final class FamilyHomilyBubbleAlert {
  FamilyHomilyBubbleAlert._();

  static const _dismissKey = 'facebaby_family_homily_bubble_dismiss_v1';

  static String _todayKey() => FamilyDateKeys.todayCompact();

  static Future<void> onHomilyReady() async {
    if (!FeatureAccess.canUseAiFamilyHomily) return;
    if (await FamilyHomilyReadPrefs.isTodayRead()) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_dismissKey) == _todayKey()) return;
    FamilyHomilyReadyNotifier.tick();
  }

  static Future<bool> shouldShowInBubble() async {
    if (!FeatureAccess.canUseAiFamilyHomily) return false;
    if (await FamilyHomilyReadPrefs.isTodayRead()) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_dismissKey) == _todayKey()) return false;
    final cached = await FamilyHomilyService().loadTodayCached();
    return cached != null && cached.homilyText.trim().isNotEmpty;
  }

  static Future<void> dismissForToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissKey, _todayKey());
    FamilyHomilyReadyNotifier.tick();
  }
}

abstract final class FamilyHomilyReadyNotifier {
  FamilyHomilyReadyNotifier._();

  static final ValueNotifier<int> generation = ValueNotifier<int>(0);

  static void tick() => generation.value++;
}

abstract final class FamilyHomilyReadPrefs {
  FamilyHomilyReadPrefs._();

  static const _readDateKey = 'facebaby_family_homily_read_date_v1';

  static String _todayKey() => FamilyDateKeys.todayCompact();

  static Future<bool> isTodayRead() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_readDateKey) == _todayKey();
  }

  static Future<void> markTodayRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_readDateKey, _todayKey());
    await FamilyHomilyUnreadBadge.refresh();
  }

  static Future<void> clearIfNewDay() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_readDateKey);
    final today = _todayKey();
    if (stored != null && stored != today) {
      await FamilyHomilyUnreadBadge.refresh();
    }
  }
}
