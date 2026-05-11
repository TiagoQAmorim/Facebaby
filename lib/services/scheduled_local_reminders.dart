import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_locale.dart';
import '../controllers/current_baby_controller.dart';
import '../controllers/sleep_timer_controller.dart';
import '../i18n/app_i18n.dart';
import 'app_database.dart';
import 'home_prefs.dart';
import 'local_notifications_service.dart';
import 'notification_nav.dart';
import 'sleep_routine.dart';

/// Reagenda alertas no sistema operativo (funcionam com app encerrada).
abstract final class ScheduledLocalReminders {
  ScheduledLocalReminders._();

  static const feedId = 6101;
  static const diaperId = 6102;
  static const sleepApproachId = 6105;
  static const sleepOverdueId = 6106;
  static const growthStaleId = 6110;

  static const List<int> allScheduledIds = [
    feedId,
    diaperId,
    sleepApproachId,
    sleepOverdueId,
    growthStaleId,
  ];

  static const _prefsKeyFeedScheduleSigV1 = 'facebaby_scheduled_feed_sig_v1';
  static const _prefsKeyDiaperScheduleSigV1 = 'facebaby_scheduled_diaper_sig_v1';
  static const _prefsKeyGrowthStaleSigV1 = 'facebaby_scheduled_growth_stale_sig_v1';
  /// Reenvio quando já está «em atraso» e o alarme pode não ter disparado (ex.: sem permissão de alarmas exactos).
  static const _prefsKeyFeedOverdueSnoozeMs = 'facebaby_feed_overdue_snooze_ms_v1';

  /// Sono: identidade do par de alarmas (bebé + último fim de sono + regras). Evita cancelar/rescrever a cada minuto.
  static const _prefsKeySleepSigV2 = 'facebaby_scheduled_sleep_sig_v2';
  /// Se ambos os momentos já passaram mas o utilizador não recebeu push, re-agendar com intervalo (~25 min como amamentação).
  static const _prefsKeySleepMissedCatchupSnoozeMs = 'facebaby_scheduled_sleep_missed_snooze_ms_v2';

  static String _feedingScheduleSig({required int babyId, required DateTime lastFeedEnd, required int intervalMin}) {
    return '$babyId|${lastFeedEnd.toIso8601String()}|$intervalMin|${kAppLanguage.lang.name}';
  }

  static String _diaperScheduleSig({required int babyId, required DateTime lastDiaperAt}) {
    return '$babyId|${lastDiaperAt.toIso8601String()}|${kAppLanguage.lang.name}';
  }

  static String _growthStaleSig({required int babyId, required DateTime lastMeasuredAt}) {
    return '$babyId|${lastMeasuredAt.toIso8601String()}|${kAppLanguage.lang.name}';
  }

  /// Idempotente: reagenda alarmes do SO a partir da BD.
  ///
  /// Importante: **não** cancelar todos os IDs no início e depois falhar em re-agendar — o [ReminderMonitor]
  /// corre ~1/min com a app aberta e apagava o alarme de amamentação quando estava overdue + mesma assinatura (noop).
  static Future<void> sync({required int? babyId}) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    final svc = LocalNotificationsService.instance;

    if (babyId == null) {
      await svc.cancelAllRoutineSchedules(allScheduledIds);
      return;
    }

    /// IDs antigos de “show imediato” — mantém compat e limpa lixo.
    await svc.cancelNotificationIds(LocalNotificationsService.legacyImmediateReminderIds);

    final strings = S(kAppLanguage.lang);
    final now = DateTime.now();

    if (HomePrefs.feedingAlertsEnabled.value) {
      final lastFeed = await AppDatabase.instance.latestBreastOrBottleFeedingEndedAt(babyId: babyId);
      if (lastFeed != null) {
        // Default por idade (se a mãe nunca customizou, HomePrefs já devolve recomendado).
        final intervalMin = await HomePrefs.getFeedingAlertIntervalMinutes();
        final when = lastFeed.add(Duration(minutes: intervalMin));
        final prefs = await SharedPreferences.getInstance();
        final sig = _feedingScheduleSig(babyId: babyId, lastFeedEnd: lastFeed, intervalMin: intervalMin);
        final prevSig = prefs.getString(_prefsKeyFeedScheduleSigV1);

        // Se já passou do horário, ainda assim agenda um lembrete “em breve” (senão o utilizador vê o banner na app
        // mas nunca recebe push porque o trigger ficaria no passado).
        final effectiveWhen = _isFutureTrigger(when, now) ? when : now.add(const Duration(seconds: 8));

        // Evita re-agendar o mesmo lembrete a cada minuto quando continua overdue — mas **não** cancelar o ID antes.
        if (prevSig == sig && !_isFutureTrigger(when, now)) {
          // Já passou do intervalo: se o SO não disparou (alarmas inexactos / permissões), re-tenta de ~25 em ~25 min.
          final lastSnooze = prefs.getInt(_prefsKeyFeedOverdueSnoozeMs) ?? 0;
          final nowMs = now.millisecondsSinceEpoch;
          if (nowMs - lastSnooze > const Duration(minutes: 25).inMilliseconds) {
            await svc.cancelNotificationIds([feedId]);
            final ok = await _safeSchedule(() => svc.scheduleZoned(
                  id: feedId,
                  title: strings.homeTimeToFeed,
                  body: strings.scheduledFeedingReminderBody,
                  whenLocal: now.add(const Duration(seconds: 12)),
                  payload: NotificationNav.payloadFeeding,
                ));
            if (ok) {
              await prefs.setInt(_prefsKeyFeedOverdueSnoozeMs, nowMs);
            }
          }
        } else if (prevSig == sig && _isFutureTrigger(when, now)) {
          // Horário ainda no futuro e nada mudou: mantém agendamento existente.
        } else {
          await svc.cancelNotificationIds([feedId]);
          final ok = await _safeSchedule(() => svc.scheduleZoned(
                id: feedId,
                title: strings.homeTimeToFeed,
                body: strings.scheduledFeedingReminderBody,
                whenLocal: effectiveWhen,
                payload: NotificationNav.payloadFeeding,
              ));
          if (ok) {
            await prefs.setString(_prefsKeyFeedScheduleSigV1, sig);
            await prefs.remove(_prefsKeyFeedOverdueSnoozeMs);
          }
        }
      } else {
        await svc.cancelNotificationIds([feedId]);
      }
    } else {
      await svc.cancelNotificationIds([feedId]);
    }

    if (HomePrefs.diaperAlertsEnabled.value) {
      final lastDiaper = await AppDatabase.instance.latestDiaperChangedAt(babyId: babyId);
      if (lastDiaper != null) {
        const intervalMin = 210;
        final when = lastDiaper.add(const Duration(minutes: intervalMin));
        final prefs = await SharedPreferences.getInstance();
        final sig = _diaperScheduleSig(babyId: babyId, lastDiaperAt: lastDiaper);
        final prevSig = prefs.getString(_prefsKeyDiaperScheduleSigV1);
        final effectiveWhen = _isFutureTrigger(when, now) ? when : now.add(const Duration(seconds: 8));

        if (prevSig == sig && !_isFutureTrigger(when, now)) {
          // overdue estável: não cancelar nem re-spammar
        } else if (prevSig == sig && _isFutureTrigger(when, now)) {
          // futuro estável
        } else {
          await svc.cancelNotificationIds([diaperId]);
          final ok = await _safeSchedule(() => svc.scheduleZoned(
                id: diaperId,
                title: strings.scheduledDiaperReminderTitle,
                body: strings.scheduledDiaperReminderBody,
                whenLocal: effectiveWhen,
                payload: NotificationNav.payloadDiaper,
              ));
          if (ok) {
            await prefs.setString(_prefsKeyDiaperScheduleSigV1, sig);
          }
        }
      } else {
        await svc.cancelNotificationIds([diaperId]);
      }
    } else {
      await svc.cancelNotificationIds([diaperId]);
    }


    if (HomePrefs.sleepAlertsEnabled.value) {
      final prefs = await SharedPreferences.getInstance();
      await SleepTimerController.instance.init();
      final babyIsInSleepSession = SleepTimerController.instance.isTracking &&
          SleepTimerController.instance.babyId == babyId;

      if (babyIsInSleepSession) {
        // Sono a decorrer (cronómetro): não avisar “hora de dormir” — a BD ainda tem o fim do sono anterior.
        await svc.cancelNotificationIds([sleepApproachId, sleepOverdueId]);
        await prefs.remove(_prefsKeySleepSigV2);
        await prefs.remove(_prefsKeySleepMissedCatchupSnoozeMs);
      } else {
      final row = CurrentBabyController.instance.currentBabyRow;
      final birthRaw = row?['birth_date'] as String?;
      final birth = DateTime.tryParse(birthRaw ?? '');
      final months = SleepRoutine.monthsOld(birth);
      final w = SleepRoutine.windowForMonths(months);
      final maxW = (HomePrefs.sleepAwakeMaxOverrideMinutes.value > 0)
          ? HomePrefs.sleepAwakeMaxOverrideMinutes.value
          : w.maxAwakeMin;
      final approachBefore = (HomePrefs.sleepApproachBeforeMinutes.value > 0)
          ? HomePrefs.sleepApproachBeforeMinutes.value
          : 15;

      final lastEnd = await AppDatabase.instance.latestCompletedSleepEnd(babyId: babyId);
      if (lastEnd == null) {
        await svc.cancelNotificationIds([sleepApproachId, sleepOverdueId]);
        await prefs.remove(_prefsKeySleepSigV2);
        await prefs.remove(_prefsKeySleepMissedCatchupSnoozeMs);
      } else {
        final overdueAt = lastEnd.add(Duration(minutes: maxW));
        final approachAt =
            maxW > approachBefore ? lastEnd.add(Duration(minutes: maxW - approachBefore)) : overdueAt;

        final sleepSig =
            '$babyId|${lastEnd.toIso8601String()}|$maxW|$approachBefore|${kAppLanguage.lang.name}';
        final prevSleepSig = prefs.getString(_prefsKeySleepSigV2);
        final approachStillAhead = maxW > approachBefore ? _isFutureTrigger(approachAt, now) : false;
        final overdueStillAhead = _isFutureTrigger(overdueAt, now);

        if (prevSleepSig == sleepSig) {
          if (approachStillAhead || overdueStillAhead) {
            // Regra e referência não mudaram e ainda há lembrete válido por vir: não voltar a
            // cancelar/reagendar a cada tick (estraga alarmas em alguns Android e atrasa no iOS).
          } else {
            // Ciclo já passou (ou SO não disparou): re-armar com espaçamento, como nas amamentações.
            final nowMs = now.millisecondsSinceEpoch;
            final lastCatch = prefs.getInt(_prefsKeySleepMissedCatchupSnoozeMs) ?? 0;
            if (nowMs - lastCatch > const Duration(minutes: 25).inMilliseconds) {
              await svc.cancelNotificationIds([sleepOverdueId]);
              final okCatch = await _safeSchedule(() => svc.scheduleZoned(
                    id: sleepOverdueId,
                    title: strings.sleepNotifTitle,
                    body: strings.sleepNotifOverdueBody,
                    whenLocal: now.add(const Duration(seconds: 12)),
                    payload: NotificationNav.payloadSleep,
                  ));
              if (okCatch) await prefs.setInt(_prefsKeySleepMissedCatchupSnoozeMs, nowMs);
            }
          }
        } else {
          await prefs.remove(_prefsKeySleepMissedCatchupSnoozeMs);
          await svc.cancelNotificationIds([sleepApproachId, sleepOverdueId]);
          await prefs.setString(_prefsKeySleepSigV2, sleepSig);

          if (maxW > approachBefore) {
            await _safeSchedule(() => svc.scheduleZoned(
                  id: sleepApproachId,
                  title: strings.sleepNotifTitle,
                  body: strings.sleepNotifBeforeBody,
                  whenLocal: approachAt,
                  payload: NotificationNav.payloadSleep,
                ));
          }

          await _safeSchedule(() => svc.scheduleZoned(
                id: sleepOverdueId,
                title: strings.sleepNotifTitle,
                body: strings.sleepNotifOverdueBody,
                whenLocal: overdueAt,
                payload: NotificationNav.payloadSleep,
              ));

          if (approachStillAhead || overdueStillAhead) await prefs.remove(_prefsKeySleepMissedCatchupSnoozeMs);
        }
      }
      }
    } else {
      await svc.cancelNotificationIds([sleepApproachId, sleepOverdueId]);
      final prefsOff = await SharedPreferences.getInstance();
      await prefsOff.remove(_prefsKeySleepSigV2);
      await prefsOff.remove(_prefsKeySleepMissedCatchupSnoozeMs);
    }

    if (HomePrefs.growthHealthAlertsEnabled.value) {
      // “Sem medições há mais de 30 dias” deve disparar mesmo com app fechado:
      // agendamos 31 dias após a última medição (peso/altura/cabeça), às 09:00 local.
      DateTime? latestGrowth;
      for (final kind in const ['weight', 'height', 'head']) {
        final list = await AppDatabase.instance.listGrowthRecords(babyId: babyId, kind: kind, limit: 1);
        if (list.isEmpty) continue;
        final iso = list.first['measured_at'] as String?;
        final dt = DateTime.tryParse(iso ?? '');
        if (dt == null) continue;
        if (latestGrowth == null || dt.isAfter(latestGrowth)) latestGrowth = dt;
      }
      if (latestGrowth == null) {
        await svc.cancelNotificationIds([growthStaleId]);
      } else {
        final day = DateTime(latestGrowth.year, latestGrowth.month, latestGrowth.day).add(const Duration(days: 31));
        final when = DateTime(day.year, day.month, day.day, 9, 0);
        final prefs = await SharedPreferences.getInstance();
        final sig = _growthStaleSig(babyId: babyId, lastMeasuredAt: latestGrowth);
        final prevSig = prefs.getString(_prefsKeyGrowthStaleSigV1);

        if (prevSig == sig && _isFutureTrigger(when, now)) {
          // estável
        } else {
          await svc.cancelNotificationIds([growthStaleId]);
          if (_isFutureTrigger(when, now)) {
            final ok = await _safeSchedule(() => svc.scheduleZoned(
                  id: growthStaleId,
                  title: strings.notifyGrowthStaleTitle,
                  body: strings.notifyGrowthStaleBody(31),
                  whenLocal: when,
                  payload: NotificationNav.payloadGrowth,
                ));
            if (ok) {
              await prefs.setString(_prefsKeyGrowthStaleSigV1, sig);
            }
          }
        }
      }
    } else {
      await svc.cancelNotificationIds([growthStaleId]);
    }
  }

  static Future<bool> _safeSchedule(Future<void> Function() fn) async {
    try {
      await fn();
      return true;
    } catch (e, st) {
      debugPrint('ScheduledLocalReminders: falha ao agendar: $e\n$st');
      return false;
    }
  }

  static bool _isFutureTrigger(DateTime when, DateTime now) {
    return when.isAfter(now.add(const Duration(seconds: 5)));
  }
}
