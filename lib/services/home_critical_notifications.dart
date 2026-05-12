import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_locale.dart';
import '../i18n/app_i18n.dart';
import '../models/consultation_record.dart';
import '../models/vaccine_record.dart';
import 'consultation_reminder_scheduler.dart';
import 'home_prefs.dart';
import 'local_notifications_service.dart';
import 'notification_nav.dart';
import 'scheduled_local_reminders.dart';
import 'vaccine_reminder_scheduler.dart';

/// Fallback robusto para os alertas críticos vistos no banner da Home
/// (“Cuidados que precisam de atenção”).
///
/// Caminho fiável: usa [LocalNotificationsService.show] (entrega imediata) —
/// não depende de `scheduleZoned` / AlarmManager / permissão de alarmas exatos.
/// Partilha as chaves de snooze com [ScheduledLocalReminders] para que ambos
/// os caminhos (timer do `ReminderMonitor` + banner da Home) convirjam no mesmo
/// dedup e nunca dupliquem o aviso.
///
/// Inclui também **consultas** e **vacinas** quando o banner da Home mostra chip
/// de consulta ou vacinas do dia — o agendamento via SO pode falhar em alguns
/// Android; o `show()` garante receber o aviso na bandeja e na inbox interna.
class HomeCriticalNotifications {
  HomeCriticalNotifications._();
  static final HomeCriticalNotifications instance = HomeCriticalNotifications._();

  // Mesmos prefs que [ScheduledLocalReminders] usa para gating no estado overdue.
  static const _feedKey = 'facebaby_feed_overdue_snooze_ms_v1';
  static const _sleepKey = 'facebaby_scheduled_sleep_missed_snooze_ms_v2';
  static const _diaperKey = 'facebaby_diaper_overdue_snooze_ms_v1';

  static const Duration _minBetweenRefires = Duration(minutes: 25);

  /// Consultas / vacinas do dia: intervalo maior — o [ReminderMonitor] pode correr
  /// muitas vezes ao abrir a app; evita som a repetir por `show()` com o mesmo ID
  /// que o lembrete agendado (`scheduleZoned`).
  static const Duration _minBetweenConsultVaccRefires = Duration(hours: 8);

  /// Anti-spam local (build cycle pode rebuildar várias vezes / segundo).
  DateTime? _lastInvocationAt;
  DateTime? _lastConsultVaccKickAt;

  static String _consultSnoozeKey(int id) => 'facebaby_banner_consult_${id}_snooze_ms_v2';
  static String _vaccSnoozeKey(int id) => 'facebaby_banner_vacc_${id}_snooze_ms_v2';

  static String _fmtConsultWhen(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  /// Dispara — se necessário — uma notificação nativa **agora** para cada item
  /// crítico actualmente visível no banner da Home.
  ///
  /// Idempotente:
  ///   - throttle interno de 5s para múltiplas invocações por rebuild
  ///   - dedup persistente de 25 min via SharedPreferences (mesma chave que
  ///     `ScheduledLocalReminders`).
  Future<void> kickFromBannerVisible({
    required int? babyId,
    required bool feedingCritical,
    required bool sleepCritical,
    required bool diaperCritical,
  }) async {
    if (babyId == null) return;
    if (!feedingCritical && !sleepCritical && !diaperCritical) return;

    final now = DateTime.now();
    final prev = _lastInvocationAt;
    if (prev != null && now.difference(prev) < const Duration(seconds: 5)) {
      return;
    }
    _lastInvocationAt = now;

    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e, st) {
      debugPrint('HomeCriticalNotifications: SharedPreferences error: $e\n$st');
      return;
    }

    final svc = LocalNotificationsService.instance;
    final strings = S(kAppLanguage.lang);
    final nowMs = now.millisecondsSinceEpoch;

    Future<void> fire({
      required bool active,
      required String snoozeKey,
      required int id,
      required String title,
      required String body,
      required String payload,
    }) async {
      if (!active) return;
      final prevMs = prefs.getInt(snoozeKey) ?? 0;
      if (nowMs - prevMs < _minBetweenRefires.inMilliseconds) return;
      try {
        await svc.show(id: id, title: title, body: body, payload: payload);
        await prefs.setInt(snoozeKey, nowMs);
        debugPrint('HomeCriticalNotifications.fire($id): shown ($title)');
      } catch (e, st) {
        debugPrint('HomeCriticalNotifications.fire($id) failed: $e\n$st');
      }
    }

    await fire(
      active: feedingCritical && HomePrefs.feedingAlertsEnabled.value,
      snoozeKey: _feedKey,
      id: ScheduledLocalReminders.feedId,
      title: strings.homeCriticalFeedingTitle,
      body: strings.homeCriticalFeedingSubtitle,
      payload: NotificationNav.payloadFeeding,
    );
    await fire(
      active: sleepCritical && HomePrefs.sleepAlertsEnabled.value,
      snoozeKey: _sleepKey,
      id: ScheduledLocalReminders.sleepOverdueId,
      title: strings.homeCriticalSleepTitle,
      body: strings.homeCriticalSleepSubtitle,
      payload: NotificationNav.payloadSleep,
    );
    await fire(
      active: diaperCritical && HomePrefs.diaperAlertsEnabled.value,
      snoozeKey: _diaperKey,
      id: ScheduledLocalReminders.diaperId,
      title: strings.homeCriticalDiaperTitle,
      body: strings.homeCriticalDiaperSubtitle,
      payload: NotificationNav.payloadDiaper,
    );
  }

  /// Push imediato para consulta no dia + vacinas com dose prevista **hoje**
  /// (mesmo conteúdo que os chips da Home).
  Future<void> kickConsultationAndVaccineFromBanner({
    required int? babyId,
    ConsultationRecord? consultationToday,
    required List<VaccineRecord> vaccinesDueToday,
  }) async {
    if (babyId == null) return;
    if (consultationToday == null && vaccinesDueToday.isEmpty) return;

    final now = DateTime.now();
    final prev = _lastConsultVaccKickAt;
    if (prev != null && now.difference(prev) < const Duration(seconds: 5)) {
      return;
    }
    _lastConsultVaccKickAt = now;

    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e, st) {
      debugPrint('HomeCriticalNotifications.consultVacc: prefs error: $e\n$st');
      return;
    }

    final svc = LocalNotificationsService.instance;
    final strings = S(kAppLanguage.lang);
    final nowMs = now.millisecondsSinceEpoch;

    Future<void> fireConsult(ConsultationRecord c) async {
      final key = _consultSnoozeKey(c.id);
      final prevMs = prefs.getInt(key) ?? 0;
      if (nowMs - prevMs < _minBetweenConsultVaccRefires.inMilliseconds) return;
      final titleText =
          c.title.trim().isEmpty ? strings.homeBannerChipConsultation : c.title.trim();
      final whenLabel = _fmtConsultWhen(c.occurredAt);
      try {
        await svc.show(
          id: ConsultationReminderScheduler.notificationId(c.id),
          title: strings.consultationReminderNotifTitle,
          body: strings.consultationTodayReminderNotifBody(titleText, whenLabel),
          payload: ConsultationReminderScheduler.payloadFor(c.id),
        );
        await prefs.setInt(key, nowMs);
        debugPrint('HomeCriticalNotifications: consultation push id=${c.id}');
      } catch (e, st) {
        debugPrint('HomeCriticalNotifications consultation failed: $e\n$st');
      }
    }

    Future<void> fireVacc(VaccineRecord v) async {
      final key = _vaccSnoozeKey(v.id);
      final prevMs = prefs.getInt(key) ?? 0;
      if (nowMs - prevMs < _minBetweenConsultVaccRefires.inMilliseconds) return;
      try {
        await svc.show(
          id: VaccineReminderScheduler.notificationId(v.id),
          title: strings.vaccineReminderNotifTitle,
          body: strings.vaccineReminderNotifBody(v.name),
          payload: VaccineReminderScheduler.payloadFor(v.id),
        );
        await prefs.setInt(key, nowMs);
        debugPrint('HomeCriticalNotifications: vaccine push id=${v.id}');
      } catch (e, st) {
        debugPrint('HomeCriticalNotifications vaccine failed: $e\n$st');
      }
    }

    if (consultationToday != null &&
        ConsultationReminderScheduler.shouldShowDayOfBanner(consultationToday, now)) {
      await fireConsult(consultationToday);
    }
    for (final v in vaccinesDueToday) {
      await fireVacc(v);
    }
  }
}
