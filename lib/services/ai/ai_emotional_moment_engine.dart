import 'package:flutter/foundation.dart';

import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_emotional_moment.dart';
import '../../models/daily_summary.dart';
import '../app_database.dart';
import 'ai_baby_emotional_context.dart';
import 'ai_bubble_alert_engine.dart';

/// Motor emocional da IA Babá — mesversários, TBT, conquistas e carinho espontâneo.
abstract final class AiEmotionalMomentEngine {
  AiEmotionalMomentEngine._();

  static const _maxMomentsPerDay = 3;

  /// Converte momentos em alertas para o balão flutuante.
  static Future<List<AiBubbleAlert>> buildBubbleAlerts({
    required int babyId,
    required String babyName,
    required String? babySex,
    required DateTime? birthDate,
    required S strings,
  }) async {
    final moments = await buildMoments(
      babyId: babyId,
      babyName: babyName,
      babySex: babySex,
      birthDate: birthDate,
      strings: strings,
    );
    return moments
        .map(
          (m) => AiBubbleAlert(
            id: m.id,
            prefsKey: m.prefsKey,
            priority: m.priority,
            text: m.text,
          ),
        )
        .toList();
  }

  static Future<List<AiEmotionalMoment>> buildMoments({
    required int babyId,
    required String babyName,
    required String? babySex,
    required DateTime? birthDate,
    required S strings,
  }) async {
    final ctx = await AiBabyEmotionalContext.load(
      babyId: babyId,
      babyName: babyName,
      babySex: babySex,
      birthDate: birthDate,
    );
    final now = DateTime.now();
    final out = <AiEmotionalMoment>[];

    final monthiversary = _monthiversary(ctx, strings, now);
    if (monthiversary != null) out.add(monthiversary);

    out.addAll(await _tbtMoments(ctx, strings, now));
    out.addAll(await _achievementMoments(ctx, strings, now));
    out.addAll(await _spontaneousMoments(ctx, strings, now));

    out.sort((a, b) => a.priority.compareTo(b.priority));
    final picked = out.take(_maxMomentsPerDay).toList();

    if (picked.isNotEmpty) {
      debugPrint(
        'AiEmotionalMomentEngine: babyId=$babyId moments=${picked.map((m) => m.kind.name).join(", ")}',
      );
    }
    return picked;
  }

  static AiEmotionalMoment? _monthiversary(
    AiBabyEmotionalContext ctx,
    S strings,
    DateTime now,
  ) {
    final birth = ctx.birthDate;
    if (birth == null) return null;
    final months = ctx.ageInMonths;
    if (months < 1) return null;
    if (!_isMonthiversaryDay(birth, now)) return null;

    final hint = _developmentHint(ctx, strings, months);
    final text = strings.aiEmotionalMonthiversary(ctx.name, months, hint);
    return AiEmotionalMoment(
      id: 'monthiversary_$months',
      kind: AiEmotionalMomentKind.monthiversary,
      prefsKey: 'emotional_monthiversary',
      text: text,
      priority: 3,
      shareSnippet: text,
      metadata: {'months': months},
    );
  }

  static bool _isMonthiversaryDay(DateTime birth, DateTime now) {
    if (now.isBefore(birth)) return false;
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final targetDay = birth.day > lastDay ? lastDay : birth.day;
    return now.day == targetDay;
  }

  static String _developmentHint(
    AiBabyEmotionalContext ctx,
    S strings,
    int months,
  ) {
    if (months <= 1) return strings.aiEmotionalDev1Month;
    if (months == 2) return strings.aiEmotionalDev2Months;
    if (months == 3) return strings.aiEmotionalDev3Months;
    if (months <= 5) return strings.aiEmotionalDev4to5Months;
    if (months <= 8) return strings.aiEmotionalDev6to8Months;
    if (months <= 11) return strings.aiEmotionalDev9to11Months;
    if (months < 24) return strings.aiEmotionalDev12to23Months;
    return strings.aiEmotionalDevToddler;
  }

  static Future<List<AiEmotionalMoment>> _tbtMoments(
    AiBabyEmotionalContext ctx,
    S strings,
    DateTime now,
  ) async {
    final out = <AiEmotionalMoment>[];
    final db = AppDatabase.instance;

    for (final daysAgo in const [30, 7, 365]) {
      if (daysAgo == 365 && ctx.ageInDays < 380) continue;
      if (daysAgo == 30 && ctx.ageInDays < 31) continue;
      if (daysAgo == 7 && ctx.ageInDays < 8) continue;

      final start = _dateOnly(now.subtract(Duration(days: daysAgo)));
      final end = start.add(const Duration(days: 1));
      final memories = await db.listMemoriesInDateRange(
        babyId: ctx.babyId,
        startInclusive: start,
        endExclusive: end,
      );
      if (memories.isEmpty) continue;

      final label = daysAgo == 7
          ? strings.aiEmotionalTbtWeek
          : daysAgo == 30
              ? strings.aiEmotionalTbtMonth
              : strings.aiEmotionalTbtYear;

      out.add(
        AiEmotionalMoment(
          id: 'tbt_memory_$daysAgo',
          kind: AiEmotionalMomentKind.tbtMemory,
          prefsKey: 'emotional_tbt_$daysAgo',
          text: strings.aiEmotionalTbtPhoto(ctx.name, label),
          priority: 8,
          shareSnippet: strings.aiEmotionalTbtPhoto(ctx.name, label),
          metadata: {'daysAgo': daysAgo},
        ),
      );
      break;
    }

    return out;
  }

  static Future<List<AiEmotionalMoment>> _achievementMoments(
    AiBabyEmotionalContext ctx,
    S strings,
    DateTime now,
  ) async {
    final out = <AiEmotionalMoment>[];

    final feedStreak = await _feedingStreakDays(ctx.babyId, now);
    if (feedStreak == 7) {
      out.add(
        AiEmotionalMoment(
          id: 'achieve_feed_7',
          kind: AiEmotionalMomentKind.achievement,
          prefsKey: 'emotional_achieve_feed_7',
          text: strings.aiEmotionalAchieveFeedingStreak(ctx.name, feedStreak),
          priority: 6,
        ),
      );
    }

    final totalRecords = await _approxTotalRecords(ctx.babyId);
    if (totalRecords >= 100 && totalRecords < 110) {
      out.add(
        AiEmotionalMoment(
          id: 'achieve_100',
          kind: AiEmotionalMomentKind.achievement,
          prefsKey: 'emotional_achieve_100',
          text: strings.aiEmotionalAchieve100Records(ctx.name, totalRecords),
          priority: 7,
        ),
      );
    }

    if (ctx.ageInDays >= 28 && ctx.ageInDays <= 35) {
      out.add(
        AiEmotionalMoment(
          id: 'achieve_first_month_app',
          kind: AiEmotionalMomentKind.achievement,
          prefsKey: 'emotional_achieve_first_month',
          text: strings.aiEmotionalAchieveFirstMonth(ctx.name),
          priority: 7,
        ),
      );
    }

    final sleepStable = await _sleepMoreStableThisWeek(ctx.babyId, now);
    if (sleepStable) {
      out.add(
        AiEmotionalMoment(
          id: 'achieve_sleep_week',
          kind: AiEmotionalMomentKind.achievement,
          prefsKey: 'emotional_achieve_sleep_week',
          text: strings.aiEmotionalAchieveSleepStable(ctx.name),
          priority: 10,
        ),
      );
    }

    return out;
  }

  static Future<int> _feedingStreakDays(int babyId, DateTime now) async {
    final db = AppDatabase.instance;
    var streak = 0;
    for (var i = 1; i <= 7; i++) {
      final day = _dateOnly(now.subtract(Duration(days: i)));
      final sum = await db.dailySummaryForHomePicker(
        babyId: babyId,
        calendarDay: day,
      );
      if (sum.feedings > 0) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  static Future<int> _approxTotalRecords(int babyId) async {
    final db = AppDatabase.instance;
    var total = 0;
    for (var i = 0; i < 14; i++) {
      final day = _dateOnly(DateTime.now().subtract(Duration(days: i)));
      final s = await db.dailySummaryForHomePicker(
        babyId: babyId,
        calendarDay: day,
      );
      total += s.feedings + s.diapers + s.sleepSessions;
    }
    return total * 8;
  }

  static Future<bool> _sleepMoreStableThisWeek(int babyId, DateTime now) async {
    final db = AppDatabase.instance;
    var thisWeek = 0;
    var prevWeek = 0;
    for (var i = 0; i < 7; i++) {
      final d = _dateOnly(now.subtract(Duration(days: i)));
      final s = await db.dailySummaryForHomePicker(babyId: babyId, calendarDay: d);
      thisWeek += s.sleepTotalSeconds;
    }
    for (var i = 7; i < 14; i++) {
      final d = _dateOnly(now.subtract(Duration(days: i)));
      final s = await db.dailySummaryForHomePicker(babyId: babyId, calendarDay: d);
      prevWeek += s.sleepTotalSeconds;
    }
    if (thisWeek < 6 * 3600 || prevWeek < 6 * 3600) return false;
    return thisWeek >= prevWeek + 3600;
  }

  static Future<List<AiEmotionalMoment>> _spontaneousMoments(
    AiBabyEmotionalContext ctx,
    S strings,
    DateTime now,
  ) async {
    final out = <AiEmotionalMoment>[];
    final db = AppDatabase.instance;

    final yesterday = _dateOnly(now.subtract(const Duration(days: 1)));
    final dayBefore = _dateOnly(now.subtract(const Duration(days: 2)));
    await db.ensureYesterdayDailySummarySnapshot(babyId: ctx.babyId);

    final y = await db.dailySummaryForHomePicker(
      babyId: ctx.babyId,
      calendarDay: yesterday,
    );
    final prev = await db.dailySummaryForHomePicker(
      babyId: ctx.babyId,
      calendarDay: dayBefore,
    );

    if (_sleepImproved(y, prev)) {
      out.add(
        AiEmotionalMoment(
          id: 'spont_sleep_better',
          kind: AiEmotionalMomentKind.spontaneousInsight,
          prefsKey: 'emotional_spont_sleep',
          text: strings.aiEmotionalSpontSleepBetter(ctx.name),
          priority: 12,
        ),
      );
    } else if (_feedingMoreRegular(y, prev)) {
      out.add(
        AiEmotionalMoment(
          id: 'spont_feeding_regular',
          kind: AiEmotionalMomentKind.spontaneousInsight,
          prefsKey: 'emotional_spont_feeding',
          text: strings.aiEmotionalSpontFeedingRegular(ctx.name),
          priority: 13,
        ),
      );
    }

    final phaseHint = _smilePhaseHint(ctx, strings);
    if (phaseHint != null) {
      out.add(
        AiEmotionalMoment(
          id: 'spont_development',
          kind: AiEmotionalMomentKind.spontaneousInsight,
          prefsKey: 'emotional_spont_dev',
          text: strings.aiEmotionalSpontDevelopment(ctx.name, phaseHint),
          priority: 14,
        ),
      );
    }

    if (out.isEmpty && !_isEmpty(y)) {
      out.add(
        AiEmotionalMoment(
          id: 'spont_encouragement',
          kind: AiEmotionalMomentKind.spontaneousInsight,
          prefsKey: 'emotional_spont_cheer',
          text: strings.aiEmotionalSpontEncouragement(ctx.name),
          priority: 15,
        ),
      );
    }

    if (ctx.hasReflux || ctx.hasColic) {
      out.add(
        AiEmotionalMoment(
          id: 'spont_gentle_care',
          kind: AiEmotionalMomentKind.spontaneousInsight,
          prefsKey: 'emotional_spont_gentle',
          text: strings.aiEmotionalSpontGentleCare(ctx.name),
          priority: 16,
        ),
      );
    }

    return out;
  }

  static bool _sleepImproved(DailySummary y, DailySummary prev) =>
      y.sleepTotalSeconds > 0 &&
      prev.sleepTotalSeconds > 0 &&
      y.sleepTotalSeconds >= prev.sleepTotalSeconds + 1800;

  static bool _feedingMoreRegular(DailySummary y, DailySummary prev) =>
      y.feedings >= 4 &&
      prev.feedings >= 3 &&
      (y.feedings - prev.feedings).abs() <= 1;

  static String? _smilePhaseHint(AiBabyEmotionalContext ctx, S strings) {
    if (ctx.ageInWeeks >= 6 && ctx.ageInWeeks <= 12) {
      return strings.aiEmotionalSpontSmilePhase;
    }
    return null;
  }

  static bool _isEmpty(DailySummary s) =>
      s.feedings == 0 && s.diapers == 0 && s.sleepTotalSeconds == 0;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
