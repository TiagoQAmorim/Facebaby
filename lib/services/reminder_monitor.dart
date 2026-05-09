import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app/app_locale.dart';
import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import 'app_database.dart';
import 'diaper_events.dart';
import 'feeding_events.dart';
import 'growth_events.dart';
import 'home_prefs.dart';
import 'sleep_events.dart';
import 'local_notifications_service.dart';
import 'notification_nav.dart';
import 'consultation_reminder_scheduler.dart';
import 'scheduled_local_reminders.dart';
import 'health_calendar_events.dart';
import 'vaccine_reminder_scheduler.dart';

class ReminderMonitor {
  ReminderMonitor._();

  static final ReminderMonitor instance = ReminderMonitor._();

  Timer? _timer;
  bool _started = false;

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

    // Periodic check while app is open.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
    _check();
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
    _timer?.cancel();
    _timer = null;
  }

  void onAppResumed() {
    _check();
  }

  void _kick() {
    _check();
  }

  Future<void> _check() async {
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
}

