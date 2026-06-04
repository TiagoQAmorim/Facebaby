import 'package:shared_preferences/shared_preferences.dart';

import '../../i18n/app_i18n.dart';
import 'ai_bubble_alert_engine.dart';
import 'ai_bubble_queue_lifecycle.dart';
import 'ai_emotional_moment_engine.dart';

/// O que pode entrar no balão flutuante vs. o banner do bebê na Home.
abstract final class AiBubbleMessagePolicy {
  /// Alertas já mostrados no banner (chips críticos + consulta/vacina).
  static const bannerHandledPrefsKeys = {
    'alert_feed',
    'alert_sleep',
    'alert_sleep_approach',
    'alert_diaper',
    'alert_consult',
    'alert_vaccine',
  };

  /// Regras extras de IA no balão entram aqui depois (fora do banner).
  static Future<List<AiBubbleAlert>> buildExtraAiAlerts({
    required int babyId,
    required String babyName,
    required String? babySex,
    required DateTime? birthDate,
    required dynamic strings,
  }) async {
    final s = strings is S ? strings : const S(AppLang.pt);
    final prefs = await SharedPreferences.getInstance();
    final anchor = await AiBubbleQueueLifecycle.ensureAnchorDay(
      babyId: babyId,
      prefs: prefs,
    );
    final daysOnApp =
        DateTime.now().difference(anchor).inDays.clamp(0, 9999);
    if (daysOnApp < 1) return const [];

    final alerts = await AiEmotionalMomentEngine.buildBubbleAlerts(
      babyId: babyId,
      babyName: babyName,
      babySex: babySex,
      birthDate: birthDate,
      strings: s,
      anchorDay: anchor,
      daysOnApp: daysOnApp,
    );
    return alerts
        .where((a) => a.prefsKey != 'emotional_spont_dev')
        .toList();
  }

  static bool isShownOnHomeBanner(AiBubbleAlert alert) =>
      bannerHandledPrefsKeys.contains(alert.prefsKey);

  /// Contextuais do motor local, sem duplicar o banner (para uso futuro).
  static Future<List<AiBubbleAlert>> contextualExcludingBanner({
    required int babyId,
    required String babyName,
    required String? babySex,
    required DateTime? birthDate,
    required S strings,
  }) async {
    final all = await AiBubbleAlertEngine.buildContextualAlerts(
      babyId: babyId,
      babyName: babyName,
      babySex: babySex,
      birthDate: birthDate,
      strings: strings,
    );
    return all.where((a) => !isShownOnHomeBanner(a)).toList();
  }
}
