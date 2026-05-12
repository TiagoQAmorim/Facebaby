import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app/app_locale.dart';
import '../controllers/current_baby_controller.dart';
import '../controllers/sleep_timer_controller.dart';
import '../i18n/app_i18n.dart';
import '../models/consultation_record.dart';
import '../models/vaccine_record.dart';
import 'app_database.dart';
import 'diaper_events.dart';
import 'feeding_events.dart';
import 'growth_events.dart';
import 'home_critical_notifications.dart';
import 'home_prefs.dart';
import 'sleep_events.dart';
import 'local_notifications_service.dart';
import 'notification_nav.dart';
import 'consultation_reminder_scheduler.dart';
import 'scheduled_local_reminders.dart';
import 'sleep_routine.dart';
import 'health_calendar_events.dart';
import 'vaccine_reminder_scheduler.dart';

class ReminderMonitor {
  ReminderMonitor._();

  static final ReminderMonitor instance = ReminderMonitor._();

  Timer? _timer;
  bool _started = false;

  /// Garante que [_runCheck] não corre em paralelo (vários listeners + resume + timer).
  Future<void> _checkChain = Future<void>.value();

  int? _growthAlertsBabyId;
  int? _lastWeightLossNotifiedRecordId;

  void start() {
    if (_started) return;
    _started = true;

    CurrentBabyController.instance.addListener(_kick);
    kAppLanguage.addListener(_kick);
    FeedingEvents.revision.addListener(_kick);
    DiaperEvents.revision.addListener(_kick);
    GrowthEvents.revision.addListener(_kick);
    HealthCalendarEvents.revision.addListener(_kick);
    HomePrefs.feedingAlertsEnabled.addListener(_kick);
    HomePrefs.feedingAlertIntervalMinutes.addListener(_kick);
    HomePrefs.sleepAlertsEnabled.addListener(_kick);
    HomePrefs.diaperAlertsEnabled.addListener(_kick);
    HomePrefs.growthHealthAlertsEnabled.addListener(_kick);
    SleepEvents.revision.addListener(_kick);
    SleepTimerController.instance.addListener(_kick);

    // Periodic check while app is open (sem fallback consulta/vacina — evita som a repetir).
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check(includeConsultVaccFallback: false));
    _check(includeConsultVaccFallback: true);
  }

  void stop() {
    if (!_started) return;
    _started = false;
    CurrentBabyController.instance.removeListener(_kick);
    kAppLanguage.removeListener(_kick);
    FeedingEvents.revision.removeListener(_kick);
    DiaperEvents.revision.removeListener(_kick);
    GrowthEvents.revision.removeListener(_kick);
    HealthCalendarEvents.revision.removeListener(_kick);
    HomePrefs.feedingAlertsEnabled.removeListener(_kick);
    HomePrefs.feedingAlertIntervalMinutes.removeListener(_kick);
    HomePrefs.sleepAlertsEnabled.removeListener(_kick);
    HomePrefs.diaperAlertsEnabled.removeListener(_kick);
    HomePrefs.growthHealthAlertsEnabled.removeListener(_kick);
    SleepEvents.revision.removeListener(_kick);
    SleepTimerController.instance.removeListener(_kick);
    _timer?.cancel();
    _timer = null;
  }

  void onAppResumed() {
    _check(includeConsultVaccFallback: true);
  }

  void _kick() {
    _check(includeConsultVaccFallback: true);
  }

  /// [includeConsultVaccFallback]: falso no timer periódico — o push imediato partilha ID
  /// com o lembrete agendado da vacina e, em alguns SO, cada `show()` volta a tocar som.
  Future<void> _check({bool includeConsultVaccFallback = true}) {
    _checkChain = _checkChain.catchError((Object e, StackTrace st) {
      debugPrint('ReminderMonitor._check chain: $e\n$st');
    }).then((_) => _runCheck(includeConsultVaccFallback: includeConsultVaccFallback));
    return _checkChain;
  }

  Future<void> _runCheck({required bool includeConsultVaccFallback}) async {
    final babyId = CurrentBabyController.instance.currentBabyId;

    if (babyId != _growthAlertsBabyId) {
      _growthAlertsBabyId = babyId;
      _lastWeightLossNotifiedRecordId = null;
    }

    try {
      await ScheduledLocalReminders.sync(babyId: babyId);
    } catch (e, st) {
      debugPrint('ReminderMonitor.sync: $e\n$st');
    }

    // Fallback robusto — usa `svc.show()` (igual ao botão de teste imediato) sempre
    // que detectar estado crítico, mesmo se [ScheduledLocalReminders.sync] foi
    // recusado pelo AlarmManager. Partilha dedup com o sync para nunca duplicar.
    if (babyId != null) {
      try {
        await _kickCriticalNotifications(babyId);
      } catch (e, st) {
        debugPrint('ReminderMonitor._kickCriticalNotifications: $e\n$st');
      }
    }

    if (babyId != null) {
      try {
        await ConsultationReminderScheduler.instance.rescheduleForBaby(babyId);
      } catch (e, st) {
        debugPrint('ReminderMonitor.consultations: $e\n$st');
      }
      try {
        await VaccineReminderScheduler.instance.rescheduleForBaby(babyId);
      } catch (e, st) {
        debugPrint('ReminderMonitor.vaccines: $e\n$st');
      }
      if (includeConsultVaccFallback) {
        try {
          await _kickConsultationVaccineFallback(babyId);
        } catch (e, st) {
          debugPrint('ReminderMonitor.consultVaccFallback: $e\n$st');
        }
      }
    }

    if (babyId == null) return;

    final strings = S(kAppLanguage.lang);

    if (HomePrefs.growthHealthAlertsEnabled.value) {
      // Crescimento: último peso inferior ao registo anterior (por data).
      final weights = await AppDatabase.instance.listGrowthRecords(babyId: babyId, kind: 'weight', limit: 2);
      if (weights.length >= 2) {
        final newest = weights[0];
        final prev = weights[1];
        final vn = (newest['value'] as num?)?.toDouble();
        final vp = (prev['value'] as num?)?.toDouble();
        final lastId = (newest['id'] as num?)?.toInt();
        if (vn != null && vp != null && lastId != null) {
          if (vn < vp) {
            if (_lastWeightLossNotifiedRecordId != lastId) {
              _lastWeightLossNotifiedRecordId = lastId;
              await LocalNotificationsService.instance.showGrowthAlert(
                id: 1003,
                title: strings.notifyGrowthWeightDownTitle,
                body: strings.notifyGrowthWeightDownBody,
                payload: NotificationNav.payloadGrowth,
              );
            }
          } else {
            _lastWeightLossNotifiedRecordId = null;
          }
        }
      } else {
        _lastWeightLossNotifiedRecordId = null;
      }

      // Mais de 30 dias sem qualquer medição de crescimento (peso, altura ou cabeça).
      // O alerta de “30+ dias sem medições” agora é agendado pelo SO em [ScheduledLocalReminders],
      // para funcionar com o app fechado. Aqui mantemos apenas o alerta imediato de queda de peso.
    } else {
      _lastWeightLossNotifiedRecordId = null;
    }
  }

  /// Calcula o mesmo estado “crítico” que o banner da Home e dispara notificações
  /// imediatas via [HomeCriticalNotifications] (com dedup partilhado).
  Future<void> _kickCriticalNotifications(int babyId) async {
    final now = DateTime.now();
    final db = AppDatabase.instance;

    bool feedCritical = false;
    if (HomePrefs.feedingAlertsEnabled.value) {
      final lastFeed = await db.latestBreastOrBottleFeedingEndedAt(babyId: babyId);
      if (lastFeed != null) {
        final intervalMin = await HomePrefs.getFeedingAlertIntervalMinutes();
        final effective = intervalMin < 20 ? 20 : intervalMin;
        feedCritical = now.difference(lastFeed).inMinutes >= effective;
      }
    }

    bool sleepCritical = false;
    if (HomePrefs.sleepAlertsEnabled.value) {
      final timer = SleepTimerController.instance;
      final inSession = timer.isTracking && timer.babyId == babyId;
      if (!inSession) {
        final lastSleepEnd = await db.latestCompletedSleepEnd(babyId: babyId);
        if (lastSleepEnd != null) {
          final row = await db.getBabyById(babyId);
          final birthStr = row?['birth_date'] as String?;
          final birth = DateTime.tryParse(birthStr ?? '');
          final months = SleepRoutine.monthsOld(birth);
          final w = SleepRoutine.windowForMonths(months);
          final maxAwake = (HomePrefs.sleepAwakeMaxOverrideMinutes.value > 0)
              ? HomePrefs.sleepAwakeMaxOverrideMinutes.value
              : w.maxAwakeMin;
          sleepCritical = now.difference(lastSleepEnd).inMinutes >= maxAwake;
        }
      }
    }

    bool diaperCritical = false;
    if (HomePrefs.diaperAlertsEnabled.value) {
      final lastDiaper = await db.latestDiaperChangedAt(babyId: babyId);
      if (lastDiaper != null) {
        diaperCritical = now.difference(lastDiaper).inMinutes >= 210;
      }
    }

    if (!feedCritical && !sleepCritical && !diaperCritical) return;
    await HomeCriticalNotifications.instance.kickFromBannerVisible(
      babyId: babyId,
      feedingCritical: feedCritical,
      sleepCritical: sleepCritical,
      diaperCritical: diaperCritical,
    );
  }

  /// Mesma lógica que os chips de consulta / vacina na Home: push imediato se o SO
  /// não entregou o agendamento (`scheduleZoned`).
  Future<void> _kickConsultationVaccineFallback(int babyId) async {
    final now = DateTime.now();
    final db = AppDatabase.instance;

    ConsultationRecord? consultToday;
    final consultRow = await db.nextUpcomingConsultation(babyId: babyId);
    if (consultRow != null) {
      final c = ConsultationRecord.fromRow(consultRow);
      if (ConsultationReminderScheduler.shouldShowDayOfBanner(c, now)) {
        consultToday = c;
      }
    }

    final dayStart = DateTime(now.year, now.month, now.day);
    final vaccRows = await db.listVaccinesDueOnCalendarDay(babyId: babyId, calendarDay: dayStart);
    final vaccines = vaccRows.map(VaccineRecord.fromRow).toList();

    await HomeCriticalNotifications.instance.kickConsultationAndVaccineFromBanner(
      babyId: babyId,
      consultationToday: consultToday,
      vaccinesDueToday: vaccines,
    );
  }
}

