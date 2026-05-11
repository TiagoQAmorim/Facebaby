import '../models/daily_summary.dart';
import '../models/weekly_report_snapshot.dart';
import 'app_database.dart';

/// Agrega métricas para a semana que contém [anchorDay] e a semana anterior.
abstract final class WeeklyReportService {
  WeeklyReportService._();

  static DateTime _monday(DateTime day) {
    final local = DateTime(day.year, day.month, day.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Índice 0..6 do último dia já iniciado na semana que começa em [weekMonday], relativamente a [today].
  /// Semana inteira no passado → 6; semana futura → -1.
  static int _lastIncludedDayIndex({
    required DateTime weekMonday,
    required DateTime today,
  }) {
    final mon = _dateOnly(weekMonday);
    final sun = mon.add(const Duration(days: 6));
    final t = _dateOnly(today);
    if (t.isBefore(mon)) return -1;
    if (t.isAfter(sun)) return 6;
    return t.difference(mon).inDays.clamp(0, 6);
  }

  static double _mean(Iterable<num> xs) {
    final list = xs.toList();
    if (list.isEmpty) return 0;
    return list.fold<num>(0, (a, b) => a + b) / list.length;
  }

  static double? _pctChange(double curr, double prev) {
    if (prev <= 0) return null;
    return (curr - prev) / prev * 100.0;
  }

  static WeeklyTrendBand _bandSleep(double? pct) {
    if (pct == null) return WeeklyTrendBand.unknown;
    if (pct > 5) return WeeklyTrendBand.improved;
    if (pct < -5) return WeeklyTrendBand.worse;
    return WeeklyTrendBand.stable;
  }

  static WeeklyTrendBand _bandFeeding(double? pct) {
    if (pct == null) return WeeklyTrendBand.unknown;
    if (pct.abs() < 6) return WeeklyTrendBand.stable;
    // Mais mamadas: tratamos como “variou” — UI pode mostrar seta conforme sinal.
    return pct > 0 ? WeeklyTrendBand.improved : WeeklyTrendBand.worse;
  }

  static WeeklyTrendBand _bandDiaper(double? pct) {
    if (pct == null) return WeeklyTrendBand.unknown;
    if (pct.abs() < 5) return WeeklyTrendBand.stable;
    return pct > 0 ? WeeklyTrendBand.improved : WeeklyTrendBand.worse;
  }

  static WeeklyTrendBand _bandWeight(int? deltaThis, int? deltaPrev) {
    if (deltaThis == null) return WeeklyTrendBand.unknown;
    if (deltaPrev == null || deltaPrev == 0) {
      return deltaThis > 0 ? WeeklyTrendBand.improved : WeeklyTrendBand.stable;
    }
    final diff = deltaThis - deltaPrev;
    if (diff > 20) return WeeklyTrendBand.improved;
    if (diff < -20) return WeeklyTrendBand.worse;
    return WeeklyTrendBand.stable;
  }

  /// Último peso (kg) com `measured_at` estritamente antes de [before].
  static Future<double?> _latestWeightKgBefore({
    required int babyId,
    required DateTime before,
  }) async {
    final rows = await AppDatabase.instance.listGrowthRecords(babyId: babyId, kind: 'weight', limit: 250);
    DateTime? bestT;
    double? bestV;
    for (final r in rows) {
      final t = DateTime.tryParse(r['measured_at'] as String? ?? '');
      final v = (r['value'] as num?)?.toDouble();
      if (t == null || v == null || v <= 0) continue;
      if (!t.isBefore(before)) continue;
      if (bestT == null || t.isAfter(bestT)) {
        bestT = t;
        bestV = v;
      }
    }
    return bestV;
  }

  /// Último peso na janela [start, endInclusiveDay].
  static Future<double?> _latestWeightKgInWeek({
    required int babyId,
    required DateTime weekMonday,
  }) async {
    final start = weekMonday;
    final end = weekMonday.add(const Duration(days: 7));
    final rows = await AppDatabase.instance.listGrowthRecords(babyId: babyId, kind: 'weight', limit: 250);
    DateTime? bestT;
    double? bestV;
    for (final r in rows) {
      final t = DateTime.tryParse(r['measured_at'] as String? ?? '');
      final v = (r['value'] as num?)?.toDouble();
      if (t == null || v == null || v <= 0) continue;
      if (t.isBefore(start) || !t.isBefore(end)) continue;
      if (bestT == null || t.isAfter(bestT)) {
        bestT = t;
        bestV = v;
      }
    }
    return bestV;
  }

  static Future<int?> _weekWeightDeltaGrams({
    required int babyId,
    required DateTime weekMonday,
  }) async {
    final beforeWeek = await _latestWeightKgBefore(babyId: babyId, before: weekMonday);
    final inWeek = await _latestWeightKgInWeek(babyId: babyId, weekMonday: weekMonday);
    if (beforeWeek == null || inWeek == null) return null;
    return ((inWeek - beforeWeek) * 1000).round();
  }

  static Future<WeeklyReportSnapshot> load({
    required int babyId,
    required DateTime anchorDay,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final today = _dateOnly(clock);

    final monday = _monday(anchorDay);
    final prevMonday = monday.subtract(const Duration(days: 7));

    final db = AppDatabase.instance;
    final curr = <DailySummary>[];
    final prev = <DailySummary>[];

    // Sempre recalcular a partir dos registos — evita semanas «zeradas» por snapshots
    // diários desatualizados em `daily_summary_snapshots`.
    for (var i = 0; i < 7; i++) {
      final d = monday.add(Duration(days: i));
      curr.add(await db.dailySummaryForCalendarDay(babyId: babyId, calendarDay: d));
    }
    for (var i = 0; i < 7; i++) {
      final d = prevMonday.add(Duration(days: i));
      prev.add(await db.dailySummaryForCalendarDay(babyId: babyId, calendarDay: d));
    }

    final endIdx = _lastIncludedDayIndex(weekMonday: monday, today: today);
    final aggregatedDayCount = endIdx < 0 ? 0 : endIdx + 1;

    List<DailySummary> slice(List<DailySummary> full) {
      if (endIdx < 0) return const [];
      return full.sublist(0, endIdx + 1);
    }

    final currSlice = slice(curr);
    final prevSlice = slice(prev);

    final avgSleepCurr = _mean(currSlice.map((e) => e.sleepTotalSeconds));
    final avgSleepPrev = _mean(prevSlice.map((e) => e.sleepTotalSeconds));
    final sleepPct = _pctChange(avgSleepCurr, avgSleepPrev);

    final avgFeedCurr = _mean(currSlice.map((e) => e.feedings.toDouble()));
    final avgFeedPrev = _mean(prevSlice.map((e) => e.feedings.toDouble()));
    final feedPct = _pctChange(avgFeedCurr, avgFeedPrev);

    final avgDiaperCurr = _mean(currSlice.map((e) => e.diapers.toDouble()));
    final avgDiaperPrev = _mean(prevSlice.map((e) => e.diapers.toDouble()));
    final diaperPct = _pctChange(avgDiaperCurr, avgDiaperPrev);

    final wThis = await _weekWeightDeltaGrams(babyId: babyId, weekMonday: monday);
    final wPrev = await _weekWeightDeltaGrams(babyId: babyId, weekMonday: prevMonday);

    final sleepBand = _bandSleep(sleepPct);
    final feedingBand = _bandFeeding(feedPct);
    final diaperBand = _bandDiaper(diaperPct);
    final weightBand = _bandWeight(wThis, wPrev);

    // Narrativa / destaque / padrões (chaves semânticas para i18n).
    final calm = aggregatedDayCount > 0 && avgDiaperCurr < 9 && sleepBand != WeeklyTrendBand.worse;
    final narrativeToneKey = calm ? 'calm' : 'active';

    String highlightKey = 'highlight_generic';
    if (sleepBand == WeeklyTrendBand.improved && (sleepPct ?? 0) >= 8) {
      highlightKey = 'highlight_sleep';
    } else if (feedingBand == WeeklyTrendBand.stable && avgFeedCurr > 0) {
      highlightKey = 'highlight_feeding_stable';
    } else if (diaperBand == WeeklyTrendBand.improved && (diaperPct ?? 0) > 8) {
      highlightKey = 'highlight_diaper_up';
    } else if (wThis != null && wThis > 80) {
      highlightKey = 'highlight_weight';
    }

    final patterns = <String>[];
    double weekendSleep = 0;
    if (endIdx >= 6) {
      weekendSleep = _mean([curr[5].sleepTotalSeconds, curr[6].sleepTotalSeconds]);
    } else if (endIdx == 5) {
      weekendSleep = curr[5].sleepTotalSeconds.toDouble();
    }
    double midSleep = 0;
    if (endIdx >= 1) {
      final midEndIdx = endIdx < 5 ? endIdx : 4;
      midSleep = _mean(curr.sublist(1, midEndIdx + 1).map((e) => e.sleepTotalSeconds));
    }
    if (endIdx >= 5 && weekendSleep > midSleep * 1.12 && weekendSleep > 0) {
      patterns.add('pattern_weekend_more_sleep');
    }
    final nightFeedsEstimate = currSlice.fold<int>(0, (a, d) => a + d.feedings);
    if (nightFeedsEstimate > 0 && feedPct != null && feedPct < -8) {
      patterns.add('pattern_feeding_down');
    }
    if (patterns.isEmpty) {
      patterns.add('pattern_default');
    }

    return WeeklyReportSnapshot(
      weekMonday: monday,
      currentWeekDays: curr,
      previousWeekDays: prev,
      aggregatedDayCount: aggregatedDayCount,
      sleepBand: sleepBand,
      sleepPctVsPrev: sleepPct,
      feedingBand: feedingBand,
      feedingPctVsPrev: feedPct,
      avgDailyFeedings: avgFeedCurr,
      diaperBand: diaperBand,
      diaperPctVsPrev: diaperPct,
      avgDailyDiapers: avgDiaperCurr,
      weightBand: weightBand,
      weightDeltaGramsThisWeek: wThis,
      weightDeltaGramsPrevWeek: wPrev,
      narrativeToneKey: narrativeToneKey,
      highlightKey: highlightKey,
      patternKeys: patterns,
      moodSamplesWeek: const [],
    );
  }

  /// Horas de sono por dia (lista Seg–Dom), como fração de hora para gráfico.
  static List<double> sleepHoursPerDay(List<DailySummary> days) {
    return days
        .map((d) => d.sleepTotalSeconds / 3600.0)
        .toList(growable: false);
  }

  static double avgSleepHours(List<DailySummary> days) {
    if (days.isEmpty) return 0;
    final sec = days.fold<int>(0, (a, d) => a + d.sleepTotalSeconds);
    return sec / (days.length * 3600.0);
  }

  static String formatHoursMinutes(double hours) {
    if (hours <= 0) return '0m';
    final totalMin = (hours * 60).round();
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m';
  }

  static double? pctVsPrevWeekAvgSleep(List<DailySummary> curr, List<DailySummary> prev) {
    final a = avgSleepHours(curr);
    final b = avgSleepHours(prev);
    return _pctChange(a, b);
  }
}
