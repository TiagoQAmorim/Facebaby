import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/current_baby_controller.dart';
import 'exact_alarm_android.dart';
import 'feeding_routine.dart';
import 'local_notifications_service.dart';
import 'measurement_units_prefs.dart';

/// Preferences that affect Home shortcuts (not tied to a specific baby).
class HomePrefs {
  static const _feedingEarlyKey = 'facebaby_feeding_session_before_7m';
  static const _aiMicEnabledKey = 'facebaby_ai_mic_enabled';
  static const _aiNannyAutoReadKey = 'facebaby_ai_nanny_auto_read';
  static const _feedingAlertsEnabledKey = 'facebaby_feeding_alerts_enabled';
  static const _feedingAlertIntervalMinKey = 'facebaby_feeding_alert_interval_min';
  static const _sleepAlertsEnabledKey = 'facebaby_sleep_alerts_enabled';
  static const _sleepAwakeMaxOverrideMinKey = 'facebaby_sleep_awake_max_override_min';
  static const _sleepAwakeApproachBeforeMinKey = 'facebaby_sleep_awake_approach_before_min';
  static const _diaperAlertsEnabledKey = 'facebaby_diaper_alerts_enabled';
  static const _growthHealthAlertsEnabledKey = 'facebaby_growth_health_alerts_enabled';
  static const _exactAlarmPromptedKey = 'facebaby_exact_alarm_prompted_v1';
  static const _weeklyWinnerCongratsWeekKey = 'facebaby_weekly_winner_congrats_week_v1';

  static const int feedingAlertIntervalMinClamp = 20;
  static const int feedingAlertIntervalMaxClamp = 360;
  static const int sleepAwakeMaxMinClamp = 30;
  static const int sleepAwakeMaxMaxClamp = 720;
  static const int sleepApproachBeforeMinClamp = 5;
  static const int sleepApproachBeforeMaxClamp = 60;

  /// Live value so screens can react immediately to changes.
  static final ValueNotifier<bool> aiMicEnabled = ValueNotifier<bool>(false);
  /// Lê em voz alta cada resposta nova da IA Babá (voz neural quando disponível).
  static final ValueNotifier<bool> aiNannyAutoReadEnabled = ValueNotifier<bool>(true);
  /// Notificações locais de intervalo entre amamentações (peito/mamadeira).
  static final ValueNotifier<bool> feedingAlertsEnabled = ValueNotifier<bool>(true);
  /// Minutos após o último registro ao peito ou mamadeira para disparar o aviso.
  static final ValueNotifier<int> feedingAlertIntervalMinutes = ValueNotifier<int>(feedingAlertIntervalMinClamp);
  /// Lembretes suaves com base na janela de sono (último sono terminado + idade).
  static final ValueNotifier<bool> sleepAlertsEnabled = ValueNotifier<bool>(true);
  /// Override do limite máximo (vigília) em minutos. `0` = usar tabela por idade.
  static final ValueNotifier<int> sleepAwakeMaxOverrideMinutes = ValueNotifier<int>(0);
  /// Quantos minutos antes do limite máximo para disparar o aviso “aproximando”. `0` = default (15).
  static final ValueNotifier<int> sleepApproachBeforeMinutes = ValueNotifier<int>(0);
  /// Push local após tempo sugerido desde a última troca (`ScheduledLocalReminders`).
  static final ValueNotifier<bool> diaperAlertsEnabled = ValueNotifier<bool>(true);
  /// Avisos de crescimento (peso inferior ao anterior, sem medições há 30 dias).
  static final ValueNotifier<bool> growthHealthAlertsEnabled = ValueNotifier<bool>(true);

  static Future<void> init() async {
    await MeasurementUnitsPrefs.init();
    final enabled = await getAiMicEnabled();
    aiMicEnabled.value = enabled;
    aiNannyAutoReadEnabled.value = await getAiNannyAutoReadEnabled();
    feedingAlertsEnabled.value = await getFeedingAlertsEnabled();
    feedingAlertIntervalMinutes.value = await getFeedingAlertIntervalMinutes();
    sleepAlertsEnabled.value = await getSleepAlertsEnabled();
    sleepAwakeMaxOverrideMinutes.value = await getSleepAwakeMaxOverrideMinutes();
    sleepApproachBeforeMinutes.value = await getSleepApproachBeforeMinutes();
    diaperAlertsEnabled.value = await getDiaperAlertsEnabled();
    growthHealthAlertsEnabled.value = await getGrowthHealthAlertsEnabled();

    // Se os alertas já vêm ativos por default, ainda precisamos pedir permissão ao SO (Android 13+ / iOS).
    // Antes isto só acontecia ao mexer manualmente nos interruptores.
    if (!kIsWeb &&
        (feedingAlertsEnabled.value || sleepAlertsEnabled.value || diaperAlertsEnabled.value || growthHealthAlertsEnabled.value)) {
      await LocalNotificationsService.instance.requestPermission();
      await _maybePromptExactAlarmIfNeeded();
    }
  }

  /// Android 12+ pode bloquear/atrasar alarmes exactos; sem isto alguns OEMs praticamente só disparam
  /// quando o app volta ao foreground. Abrimos o ecrã do sistema **uma vez** para o utilizador permitir.
  static Future<void> _maybePromptExactAlarmIfNeeded() async {
    if (kIsWeb) return;
    try {
      final needsFix = await ExactAlarmAndroid.needsExactAlarmFix();
      if (!needsFix) return;
      final p = await SharedPreferences.getInstance();
      if (p.getBool(_exactAlarmPromptedKey) == true) return;
      await p.setBool(_exactAlarmPromptedKey, true);
      await ExactAlarmAndroid.openExactAlarmSettings();
    } catch (_) {}
  }

  static Future<bool> getFeedingSessionBeforeSevenMonths() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_feedingEarlyKey) ?? false;
  }

  static Future<void> setFeedingSessionBeforeSevenMonths(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_feedingEarlyKey, value);
  }

  static Future<bool> getAiMicEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_aiMicEnabledKey) ?? false;
  }

  static Future<void> setAiMicEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_aiMicEnabledKey, value);
    aiMicEnabled.value = value;
  }

  static Future<bool> getAiNannyAutoReadEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_aiNannyAutoReadKey) ?? true;
  }

  static Future<void> setAiNannyAutoReadEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_aiNannyAutoReadKey, value);
    aiNannyAutoReadEnabled.value = value;
  }

  static Future<bool> getFeedingAlertsEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_feedingAlertsEnabledKey) ?? true;
  }

  static Future<void> setFeedingAlertsEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_feedingAlertsEnabledKey, value);
    feedingAlertsEnabled.value = value;
    if (value && !kIsWeb) {
      await LocalNotificationsService.instance.requestPermission();
      await _maybePromptExactAlarmIfNeeded();
    }
  }

  static Future<int> getFeedingAlertIntervalMinutes() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getInt(_feedingAlertIntervalMinKey);
    if (v != null) return v.clamp(feedingAlertIntervalMinClamp, feedingAlertIntervalMaxClamp);

    // Default recomendado por idade (tabela do produto) quando a mãe ainda não customizou.
    final row = CurrentBabyController.instance.currentBabyRow;
    final birthRaw = row?['birth_date'] as String?;
    final birth = DateTime.tryParse(birthRaw ?? '');
    final months = FeedingRoutine.monthsOld(birth);
    final rec = FeedingRoutine.recommendedIntervalMinutes(months);
    return rec.clamp(feedingAlertIntervalMinClamp, feedingAlertIntervalMaxClamp);
  }

  static Future<void> setFeedingAlertIntervalMinutes(int value) async {
    final p = await SharedPreferences.getInstance();
    final clamped = value.clamp(feedingAlertIntervalMinClamp, feedingAlertIntervalMaxClamp);
    await p.setInt(_feedingAlertIntervalMinKey, clamped);
    feedingAlertIntervalMinutes.value = clamped;
  }

  static Future<int> getSleepAwakeMaxOverrideMinutes() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getInt(_sleepAwakeMaxOverrideMinKey) ?? 0;
    if (v == 0) return 0;
    return v.clamp(sleepAwakeMaxMinClamp, sleepAwakeMaxMaxClamp);
  }

  /// `0` volta para o default por idade (tabela).
  static Future<void> setSleepAwakeMaxOverrideMinutes(int value) async {
    final p = await SharedPreferences.getInstance();
    final v = value <= 0 ? 0 : value.clamp(sleepAwakeMaxMinClamp, sleepAwakeMaxMaxClamp);
    await p.setInt(_sleepAwakeMaxOverrideMinKey, v);
    sleepAwakeMaxOverrideMinutes.value = v;
  }

  static Future<int> getSleepApproachBeforeMinutes() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getInt(_sleepAwakeApproachBeforeMinKey) ?? 0;
    if (v == 0) return 0;
    return v.clamp(sleepApproachBeforeMinClamp, sleepApproachBeforeMaxClamp);
  }

  /// `0` volta para o default (15 min).
  static Future<void> setSleepApproachBeforeMinutes(int value) async {
    final p = await SharedPreferences.getInstance();
    final v = value <= 0 ? 0 : value.clamp(sleepApproachBeforeMinClamp, sleepApproachBeforeMaxClamp);
    await p.setInt(_sleepAwakeApproachBeforeMinKey, v);
    sleepApproachBeforeMinutes.value = v;
  }

  static Future<bool> getSleepAlertsEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_sleepAlertsEnabledKey) ?? true;
  }

  static Future<void> setSleepAlertsEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_sleepAlertsEnabledKey, value);
    sleepAlertsEnabled.value = value;
    if (value && !kIsWeb) {
      await LocalNotificationsService.instance.requestPermission();
      await _maybePromptExactAlarmIfNeeded();
    }
  }

  static Future<bool> getDiaperAlertsEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_diaperAlertsEnabledKey) ?? true;
  }

  static Future<void> setDiaperAlertsEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_diaperAlertsEnabledKey, value);
    diaperAlertsEnabled.value = value;
    if (value && !kIsWeb) {
      await LocalNotificationsService.instance.requestPermission();
      await _maybePromptExactAlarmIfNeeded();
    }
  }

  static Future<bool> getGrowthHealthAlertsEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_growthHealthAlertsEnabledKey) ?? true;
  }

  static Future<void> setGrowthHealthAlertsEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_growthHealthAlertsEnabledKey, value);
    growthHealthAlertsEnabled.value = value;
    if (value && !kIsWeb) {
      await LocalNotificationsService.instance.requestPermission();
      await _maybePromptExactAlarmIfNeeded();
    }
  }

  /// `week_id` do `spotlight_current` para o qual a mãe já viu o modal de parabéns.
  static Future<String?> getWeeklyWinnerCongratsAckWeek() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_weeklyWinnerCongratsWeekKey);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  static Future<void> setWeeklyWinnerCongratsAckWeek(String weekId) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_weeklyWinnerCongratsWeekKey, weekId.trim());
  }
}
