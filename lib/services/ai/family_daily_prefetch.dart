import 'dart:async' show unawaited;

import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../models/family_message_prefs.dart';
import '../../utils/family_date_keys.dart';
import '../family_homily_read_prefs.dart';
import '../family_horoscope_read_prefs.dart';
import '../premium/feature_access.dart';
import 'family_homily_service.dart';
import 'family_horoscope_service.dart';

/// Garante homilia/horóscopo do dia em cache (ex.: após cron 7h30) e refresca balões.
abstract final class FamilyDailyPrefetch {
  FamilyDailyPrefetch._();

  static bool _started = false;
  static String _scheduledDay = '';

  static void scheduleIfNeeded(S strings) {
    if (!FeatureAccess.canUseAnyAi) return;
    final today = FamilyDateKeys.todayCompact();
    if (_scheduledDay != today) {
      _scheduledDay = today;
      _started = false;
    }
    if (_started) return;
    _started = true;
    unawaited(_run(strings));
  }

  static Future<void> _run(S strings) async {
    final prefs = FamilyMessagePrefs.fromMother(
      CurrentBabyController.instance.currentMotherRow,
    );
    final langHomily = FamilyHomilyService.languageCodeFromApp(strings);
    final langHoroscope = FamilyHoroscopeService.languageCodeFromApp(strings);

    try {
      if (prefs.showChristian) {
        await FamilyHomilyBootstrap.ensureToday(languageCode: langHomily);
      }
      if (prefs.showHoroscope) {
        await FamilyHoroscopeBootstrap.ensureToday(languageCode: langHoroscope);
      }
    } catch (_) {
      await FamilyHomilyUnreadBadge.refresh();
      await FamilyHoroscopeUnreadBadge.refresh();
    }
  }

  static void resetForTests() {
    _started = false;
    _scheduledDay = '';
  }
}
