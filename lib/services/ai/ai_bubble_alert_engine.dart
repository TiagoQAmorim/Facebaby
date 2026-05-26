import '../../controllers/sleep_timer_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../models/consultation_record.dart';
import '../../models/daily_summary.dart';
import '../../models/vaccine_record.dart';
import '../../services/app_database.dart';
import '../../services/consultation_reminder_scheduler.dart';
import '../../services/home_prefs.dart';
import '../../services/home_yesterday_baba_service.dart';
import '../../services/sleep_routine.dart';
/// Aviso contextual para o balão flutuante na Home (prioridade menor = mais urgente).
class AiBubbleAlert {
  const AiBubbleAlert({
    required this.id,
    required this.prefsKey,
    required this.text,
    required this.priority,
  });

  final String id;
  final String prefsKey;
  final String text;
  final int priority;
}

/// Gera avisos inteligentes a partir dos registros locais (sem OpenAI).
abstract final class AiBubbleAlertEngine {
  AiBubbleAlertEngine._();

  static const int _maxAlerts = 5;
  static const int _feverLookbackHours = 72;
  static const int _feverAcuteMaxHours = 20;
  static const int _feverFollowUpMaxHours = 48;
  static const int _growthStaleDays = 21;

  static Future<List<AiBubbleAlert>> buildContextualAlerts({
    required int babyId,
    required String babyName,
    required String? babySex,
    required DateTime? birthDate,
    required S strings,
  }) async {
    final name = babyName.trim().isEmpty ? strings.baby : babyName.trim();
    final now = DateTime.now();
    final db = AppDatabase.instance;
    final out = <AiBubbleAlert>[];

    // --- Saúde / agenda ---
    final symptoms = await db.listSymptomReports(babyId: babyId);
    final feverAlert = _feverFollowUpAlert(
      symptoms: symptoms,
      babyName: name,
      strings: strings,
      now: now,
    );
    if (feverAlert != null) out.add(feverAlert);

    final consultRow = await db.nextUpcomingConsultation(babyId: babyId);
    if (consultRow != null) {
      final c = ConsultationRecord.fromRow(consultRow);
      if (ConsultationReminderScheduler.shouldShowDayOfBanner(c, now)) {
        final when = _formatClock(c.occurredAt);
        final title = c.title.trim().isEmpty ? strings.consultationsTitle : c.title.trim();
        out.add(
          AiBubbleAlert(
            id: 'consult_${c.id}',
            prefsKey: 'alert_consult',
            priority: 20,
            text: strings.aiBubbleConsultToday(name, title, when),
          ),
        );
      }
    }

    final dayStart = DateTime(now.year, now.month, now.day);
    final vaccRows =
        await db.listVaccinesDueOnCalendarDay(babyId: babyId, calendarDay: dayStart);
    if (vaccRows.isNotEmpty) {
      final vaccines = vaccRows.map(VaccineRecord.fromRow).toList();
      final text = vaccines.length == 1
          ? strings.aiBubbleVaccineToday(name, vaccines.first.name.trim())
          : strings.aiBubbleVaccinesToday(name, vaccines.length);
      out.add(
        AiBubbleAlert(
          id: 'vaccine',
          prefsKey: 'alert_vaccine',
          priority: 25,
          text: text,
        ),
      );
    }

    // --- Sono em curso ---
    await SleepTimerController.instance.init();
    final timer = SleepTimerController.instance;
    if (timer.isTracking && timer.babyId == babyId && timer.startedAt != null) {
      final elapsed = timer.effectiveElapsed;
      final row = await db.getBabyById(babyId);
      final birth = DateTime.tryParse(row?['birth_date'] as String? ?? '') ?? birthDate;
      final months = SleepRoutine.monthsOld(birth);
      final w = SleepRoutine.windowForMonths(months);
      final capMin = SleepRoutine.sessionCapMinutesForWindow(w);
      if (!timer.isPaused && elapsed.inMinutes >= capMin) {
        final hours = (elapsed.inMinutes / 60).ceil().clamp(1, 24);
        out.add(
          AiBubbleAlert(
            id: 'sleep_wake_long',
            prefsKey: 'alert_sleep_wake_long',
            priority: 30,
            text: strings.aiBubbleSleepWakeLong(name, hours),
          ),
        );
      } else if (elapsed.inMinutes >= 120) {
        final h = elapsed.inHours.clamp(1, 48);
        out.add(
          AiBubbleAlert(
            id: 'sleep_tracking',
            prefsKey: 'alert_sleep_tracking',
            priority: 35,
            text: strings.aiBubbleSleepTracking(name, h),
          ),
        );
      }
    }

    // --- Rotina crítica (mesma lógica do banner da Home) ---
    if (HomePrefs.feedingAlertsEnabled.value) {
      final lastFeed = await db.latestBreastOrBottleFeedingEndedAt(babyId: babyId);
      if (lastFeed != null) {
        var intervalMin = await HomePrefs.getFeedingAlertIntervalMinutes();
        if (intervalMin < 20) intervalMin = 20;
        if (now.difference(lastFeed).inMinutes >= intervalMin) {
          out.add(
            AiBubbleAlert(
              id: 'feed_critical',
              prefsKey: 'alert_feed',
              priority: 40,
              text: strings.aiBubbleFeedingCritical(name),
            ),
          );
        }
      }
    }

    if (HomePrefs.sleepAlertsEnabled.value &&
        !(timer.isTracking && timer.babyId == babyId)) {
      final lastSleepEnd = await db.latestCompletedSleepEnd(babyId: babyId);
      if (lastSleepEnd != null) {
        final birth = birthDate ??
            DateTime.tryParse(
              (await db.getBabyById(babyId))?['birth_date'] as String? ?? '',
            );
        final months = SleepRoutine.monthsOld(birth);
        final w = SleepRoutine.windowForMonths(months);
        final maxAwake = HomePrefs.sleepAwakeMaxOverrideMinutes.value > 0
            ? HomePrefs.sleepAwakeMaxOverrideMinutes.value
            : w.maxAwakeMin;
        final approachBefore = HomePrefs.sleepApproachBeforeMinutes.value > 0
            ? HomePrefs.sleepApproachBeforeMinutes.value
            : 15;
        final awakeMin = now.difference(lastSleepEnd).inMinutes;

        if (awakeMin >= maxAwake) {
          out.add(
            AiBubbleAlert(
              id: 'sleep_critical',
              prefsKey: 'alert_sleep',
              priority: 45,
              text: strings.aiBubbleSleepCritical(name),
            ),
          );
        } else if (maxAwake > approachBefore &&
            awakeMin >= maxAwake - approachBefore) {
          out.add(
            AiBubbleAlert(
              id: 'sleep_approach',
              prefsKey: 'alert_sleep_approach',
              priority: 50,
              text: strings.aiBubbleSleepApproach(name),
            ),
          );
        }
      }
    }

    if (HomePrefs.diaperAlertsEnabled.value) {
      final lastDiaper = await db.latestDiaperChangedAt(babyId: babyId);
      if (lastDiaper != null && now.difference(lastDiaper).inMinutes >= 210) {
        out.add(
          AiBubbleAlert(
            id: 'diaper_critical',
            prefsKey: 'alert_diaper',
            priority: 55,
            text: strings.aiBubbleDiaperCritical(name),
          ),
        );
      }
    }

    // --- Crescimento ---
    if (HomePrefs.growthHealthAlertsEnabled.value) {
      final weights =
          await db.listGrowthRecords(babyId: babyId, kind: 'weight', limit: 2);
      if (weights.length >= 2) {
        final vn = (weights[0]['value'] as num?)?.toDouble();
        final vp = (weights[1]['value'] as num?)?.toDouble();
        if (vn != null && vp != null && vn < vp) {
          out.add(
            AiBubbleAlert(
              id: 'weight_down',
              prefsKey: 'alert_weight_down',
              priority: 60,
              text: strings.aiBubbleWeightDown(name),
            ),
          );
        }
      }

      DateTime? latestGrowth;
      for (final kind in const ['weight', 'height', 'head']) {
        final list = await db.listGrowthRecords(babyId: babyId, kind: kind, limit: 1);
        if (list.isEmpty) continue;
        final dt = DateTime.tryParse(list.first['measured_at'] as String? ?? '');
        if (dt == null) continue;
        if (latestGrowth == null || dt.isAfter(latestGrowth)) latestGrowth = dt;
      }
      if (latestGrowth != null) {
        final days = now.difference(latestGrowth).inDays;
        if (days >= _growthStaleDays) {
          out.add(
            AiBubbleAlert(
              id: 'growth_stale',
              prefsKey: 'alert_growth_stale',
              priority: 65,
              text: strings.aiBubbleGrowthStale(name, days),
            ),
          );
        }
      } else {
        out.add(
          AiBubbleAlert(
            id: 'growth_none',
            prefsKey: 'alert_growth_none',
            priority: 66,
            text: strings.aiBubbleGrowthNone(name),
          ),
        );
      }

      final growthHint = await _growthWatchHint(
        strings: strings,
        babyId: babyId,
        babySex: babySex,
        birthDate: birthDate,
      );
      if (growthHint != null) {
        out.add(
          AiBubbleAlert(
            id: 'growth_watch',
            prefsKey: 'alert_growth_watch',
            priority: 70,
            text: strings.aiBubbleGrowthWatch(name, growthHint),
          ),
        );
      }
    }

    // --- Hoje sem registros (tarde) ---
    if (now.hour >= 14) {
      final today = DateTime(now.year, now.month, now.day);
      final todaySum = await db.dailySummaryForHomePicker(
        babyId: babyId,
        calendarDay: today,
      );
      if (_isEmptySummary(todaySum)) {
        out.add(
          AiBubbleAlert(
            id: 'today_empty',
            prefsKey: 'alert_today_empty',
            priority: 80,
            text: strings.aiBubbleTodayEmpty(name),
          ),
        );
      }
    }

    out.sort((a, b) => a.priority.compareTo(b.priority));
    return out.take(_maxAlerts).toList();
  }

  /// Febre: mensagem por fase (aguda → acompanhamento → já melhorou?), não só “registrada”.
  static AiBubbleAlert? _feverFollowUpAlert({
    required List<Map<String, Object?>> symptoms,
    required String babyName,
    required S strings,
    required DateTime now,
  }) {
    Map<String, Object?>? feverRow;
    DateTime? feverAt;

    for (final row in symptoms) {
      if ((row['fever'] as int? ?? 0) != 1) continue;
      final at = DateTime.tryParse(row['occurred_at'] as String? ?? '');
      if (at == null) continue;
      if (feverAt == null || at.isAfter(feverAt)) {
        feverRow = row;
        feverAt = at;
      }
    }
    if (feverRow == null || feverAt == null) return null;
    var activeRow = feverRow;
    var activeAt = feverAt;

    // Sintoma mais recente sem febre → família já sinalizou melhora; não insistir.
    for (final row in symptoms) {
      final at = DateTime.tryParse(row['occurred_at'] as String? ?? '');
      if (at == null || !at.isAfter(activeAt)) continue;
      if ((row['fever'] as int? ?? 0) == 1) {
        activeRow = row;
        activeAt = at;
      } else {
        return null;
      }
    }

    final hoursSince = now.difference(activeAt).inHours;
    if (hoursSince > _feverLookbackHours) return null;

    final temp = (activeRow['temp_celsius'] as num?)?.toDouble();
    final hasTemp = temp != null && temp > 0;

    if (hoursSince >= _feverFollowUpMaxHours) {
      final days = (hoursSince / 24).ceil().clamp(1, 14);
      return AiBubbleAlert(
        id: 'fever_recovery',
        prefsKey: 'alert_fever_recovery',
        priority: 10,
        text: strings.aiBubbleFeverRecoveryCheck(babyName, days),
      );
    }

    if (hoursSince >= _feverAcuteMaxHours) {
      return AiBubbleAlert(
        id: 'fever_followup',
        prefsKey: 'alert_fever_followup',
        priority: 10,
        text: hasTemp
            ? strings.aiBubbleFeverFollowUpWithTemp(babyName, temp)
            : strings.aiBubbleFeverFollowUp(babyName),
      );
    }

    final String text;
    if (hasTemp && temp >= 38.5) {
      text = strings.aiBubbleFeverAcuteHigh(babyName, temp);
    } else if (hasTemp) {
      text = strings.aiBubbleFeverAcuteWithTemp(babyName, temp);
    } else {
      text = strings.aiBubbleFeverAcute(babyName);
    }
    return AiBubbleAlert(
      id: 'fever_acute',
      prefsKey: 'alert_fever_acute',
      priority: 10,
      text: text,
    );
  }

  static Future<String?> _growthWatchHint({
    required S strings,
    required int babyId,
    required String? babySex,
    required DateTime? birthDate,
  }) async {
    final full = await HomeYesterdayBabaService.bodyForToday(
      babyId: babyId,
      babyName: '',
      babySex: babySex,
      birthDate: birthDate,
      strings: strings,
    );
    if (full.contains(strings.homeYesterdayBabaGrowthBelow) ||
        full.contains(strings.homeYesterdayBabaBandBelow)) {
      return strings.homeAiInsightGrowthShortWatch;
    }
    return null;
  }

  static bool _isEmptySummary(DailySummary s) =>
      s.feedings == 0 &&
      s.diapers == 0 &&
      s.sleepTotalSeconds == 0 &&
      s.sleepSessions == 0;

  static String _formatClock(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
