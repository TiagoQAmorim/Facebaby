import 'dart:math' as math;

import '../models/advanced_sleep_report_snapshot.dart';
import '../models/daily_summary.dart';
import 'app_database.dart';

/// Métricas “premium” derivadas de `sleep_records` + resumos diários (semana vs semana).
abstract final class AdvancedSleepReportService {
  AdvancedSleepReportService._();

  static DateTime _monday(DateTime day) {
    final local = DateTime(day.year, day.month, day.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  static double _mean(List<double> xs) {
    if (xs.isEmpty) return 0;
    return xs.reduce((a, b) => a + b) / xs.length;
  }

  static double? _pctChange(double curr, double prev) {
    if (prev <= 0) return null;
    return (curr - prev) / prev * 100.0;
  }

  static DateTime? _parse(String? iso) => DateTime.tryParse(iso ?? '');

  static int _overlapSec(DateTime a0, DateTime a1, DateTime b0, DateTime b1) {
    final s = a0.isAfter(b0) ? a0 : b0;
    final e = a1.isBefore(b1) ? a1 : b1;
    if (!e.isAfter(s)) return 0;
    return e.difference(s).inSeconds;
  }

  /// Junta registos sem duplicar `id` ao longo de vários dias civis.
  static Future<List<Map<String, Object?>>> _sleepRowsForDaySpan({
    required int babyId,
    required DateTime firstDay,
    required DateTime lastDayInclusive,
  }) async {
    final db = AppDatabase.instance;
    final byId = <int, Map<String, Object?>>{};
    var cursor = DateTime(firstDay.year, firstDay.month, firstDay.day);
    final end = DateTime(lastDayInclusive.year, lastDayInclusive.month, lastDayInclusive.day);
    while (!cursor.isAfter(end)) {
      final rows = await db.listSleepRecordsForCalendarDay(babyId: babyId, calendarDay: cursor);
      for (final r in rows) {
        final id = (r['id'] as num?)?.toInt();
        if (id != null && id > 0) {
          byId[id] = r;
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    final list = byId.values.toList();
    list.sort((a, b) {
      final as = a['started_at'] as String? ?? '';
      final bs = b['started_at'] as String? ?? '';
      return as.compareTo(bs);
    });
    return list;
  }

  /// Janela “noite que termina na manhã de [day]”: dia anterior 18:00 → [day] 10:00.
  static (DateTime start, DateTime end) _nightWindowEnding(DateTime day) {
    final d0 = DateTime(day.year, day.month, day.day);
    final prev = d0.subtract(const Duration(days: 1));
    final start = DateTime(prev.year, prev.month, prev.day, 18, 0);
    final end = DateTime(day.year, day.month, day.day, 10, 0);
    return (start, end);
  }

  static (DateTime start, DateTime end) _dayWindow(DateTime day) {
    final d0 = DateTime(day.year, day.month, day.day);
    final s = DateTime(d0.year, d0.month, d0.day, 6, 0);
    final e = DateTime(d0.year, d0.month, d0.day, 18, 0);
    return (s, e);
  }

  static double _efficiencyForDaySessions(List<Map<String, Object?>> daySessions) {
    if (daySessions.isEmpty) return 0;
    DateTime? minS;
    DateTime? maxE;
    var sum = 0;
    for (final r in daySessions) {
      final s = _parse(r['started_at'] as String?);
      final e = _parse(r['ended_at'] as String?);
      final dur = (r['duration_sec'] as num?)?.toInt();
      if (s == null || e == null || dur == null || dur < 1) continue;
      sum += dur;
      if (minS == null || s.isBefore(minS)) minS = s;
      if (maxE == null || e.isAfter(maxE)) maxE = e;
    }
    if (minS == null || maxE == null) return 0;
    final span = maxE.difference(minS).inSeconds;
    if (span <= 0) return 100;
    return math.min(100.0, sum / span * 100.0);
  }

  static Future<double> _avgEfficiencyWeek({
    required int babyId,
    required DateTime weekMonday,
  }) async {
    final effs = <double>[];
    for (var i = 0; i < 7; i++) {
      final day = weekMonday.add(Duration(days: i));
      final rows = await AppDatabase.instance.listSleepRecordsForCalendarDay(babyId: babyId, calendarDay: day);
      if (rows.isEmpty) continue;
      effs.add(_efficiencyForDaySessions(rows));
    }
    return effs.isEmpty ? 0 : _mean(effs);
  }

  static void _accumulateNightMetrics({
    required List<Map<String, Object?>> pool,
    required DateTime weekMonday,
    required List<double> onsetMinutes,
    required List<double> awakenPerNight,
    required List<int> firstStartsMinutesFromMidnight,
  }) {
    for (var i = 0; i < 7; i++) {
      final day = weekMonday.add(Duration(days: i));
      final win = _nightWindowEnding(day);
      final overlapping = <Map<String, Object?>>[];
      for (final r in pool) {
        final s = _parse(r['started_at'] as String?);
        final e = _parse(r['ended_at'] as String?);
        if (s == null || e == null) continue;
        if (e.isAfter(win.$1) && s.isBefore(win.$2)) overlapping.add(r);
      }
      overlapping.sort((a, b) {
        final as = a['started_at'] as String? ?? '';
        final bs = b['started_at'] as String? ?? '';
        return as.compareTo(bs);
      });
      if (overlapping.isEmpty) continue;

      final first = overlapping.first;
      final fs = _parse(first['started_at'] as String?);
      if (fs != null && fs.isBefore(win.$2) && fs.isAfter(win.$1)) {
        final latency = fs.difference(win.$1).inMinutes.clamp(0, 240).toDouble();
        onsetMinutes.add(latency);
      }

      final aw = math.max(0, overlapping.length - 1);
      awakenPerNight.add(aw.toDouble());

      final fs2 = _parse(overlapping.first['started_at'] as String?);
      if (fs2 != null) {
        firstStartsMinutesFromMidnight.add(fs2.hour * 60 + fs2.minute);
      }
    }
  }

  /// Média circular dos primeiros inícios → centro da “janela ideal”.
  static ({int hour, int minute}) _idealBedtimeFromStarts(List<int> minsFromMidnight) {
    if (minsFromMidnight.isEmpty) return (hour: 19, minute: 45);
    final n = minsFromMidnight.length;
    var sx = 0.0;
    var sy = 0.0;
    for (final m in minsFromMidnight) {
      final th = 2 * math.pi * (m / (24 * 60.0));
      sx += math.cos(th);
      sy += math.sin(th);
    }
    var meanTh = math.atan2(sy / n, sx / n);
    if (meanTh < 0) meanTh += 2 * math.pi;
    var mins = (meanTh / (2 * math.pi) * 24 * 60).round();
    mins %= 24 * 60;
    if (mins < 0) mins += 24 * 60;
    final h = mins ~/ 60;
    final mi = mins % 60;
    return (hour: h, minute: mi);
  }

  static Future<AdvancedSleepReportSnapshot> load({
    required int babyId,
    required DateTime anchorDay,
  }) async {
    final monday = _monday(anchorDay);
    final prevMonday = monday.subtract(const Duration(days: 7));

    final poolStart = monday.subtract(const Duration(days: 1));
    final poolEnd = monday.add(const Duration(days: 8));

    final pool = await _sleepRowsForDaySpan(
      babyId: babyId,
      firstDay: poolStart,
      lastDayInclusive: poolEnd,
    );

    final db = AppDatabase.instance;
    final curr = <DailySummary>[];
    final prev = <DailySummary>[];
    for (var i = 0; i < 7; i++) {
      curr.add(await db.dailySummaryForCalendarDay(babyId: babyId, calendarDay: monday.add(Duration(days: i))));
    }
    for (var i = 0; i < 7; i++) {
      prev.add(await db.dailySummaryForCalendarDay(babyId: babyId, calendarDay: prevMonday.add(Duration(days: i))));
    }

    final lineHours = curr.map((d) => d.sleepTotalSeconds / 3600.0).toList(growable: false);
    final prevLineHours = prev.map((d) => d.sleepTotalSeconds / 3600.0).toList(growable: false);

    final effCurr = await _avgEfficiencyWeek(babyId: babyId, weekMonday: monday);
    final effPrev = await _avgEfficiencyWeek(babyId: babyId, weekMonday: prevMonday);

    final onsetM = <double>[];
    final awakenN = <double>[];
    final firstStarts = <int>[];
    _accumulateNightMetrics(
      pool: pool,
      weekMonday: monday,
      onsetMinutes: onsetM,
      awakenPerNight: awakenN,
      firstStartsMinutesFromMidnight: firstStarts,
    );

    var longest = 0;
    for (final r in pool) {
      final d = (r['duration_sec'] as num?)?.toInt() ?? 0;
      if (d > longest) longest = d;
    }

    final onsetAvg = onsetM.isEmpty ? 0.0 : _mean(onsetM);
    final awakenAvg = awakenN.isEmpty ? 0.0 : _mean(awakenN);
    final awakenTotal = awakenN.fold<int>(0, (a, b) => a + b.round());

    final ideal = _idealBedtimeFromStarts(firstStarts);
    final idealH = firstStarts.isEmpty ? null : ideal.hour;
    final idealMin = firstStarts.isEmpty ? null : ideal.minute;

    var daySec = 0;
    var nightSec = 0;
    for (final r in pool) {
      final s = _parse(r['started_at'] as String?);
      final e = _parse(r['ended_at'] as String?);
      final dur = (r['duration_sec'] as num?)?.toInt() ?? 0;
      if (s == null || e == null || dur < 1) continue;
      for (var i = 0; i < 7; i++) {
        final day = monday.add(Duration(days: i));
        final dw = _dayWindow(day);
        final nw = _nightWindowEnding(day);
        daySec += _overlapSec(s, e, dw.$1, dw.$2);
        nightSec += _overlapSec(s, e, nw.$1, nw.$2);
      }
    }
    final dayH = daySec / 3600.0;
    final nightH = nightSec / 3600.0;
    final dnSum = dayH + nightH;

    // --- Score heurístico 0–100 ---
    double effPts = 0;
    if (effCurr > 0) {
      effPts = ((effCurr - 65) / 25 * 35).clamp(0.0, 35.0);
    }
    final longestH = longest / 3600.0;
    var stretchPts = (longestH / 6.0 * 25).clamp(0.0, 25.0);
    if (longestH < 1.5) stretchPts *= 0.6;

    double awakenPts = 25.0;
    if (awakenAvg <= 1) {
      awakenPts = 25;
    } else if (awakenAvg <= 2.5) {
      awakenPts = 18;
    } else if (awakenAvg <= 4) {
      awakenPts = 10;
    } else {
      awakenPts = 4;
    }

    final hoursList = lineHours;
    final meanH = hoursList.isEmpty ? 0.0 : _mean(hoursList);
    double cv = 0;
    if (hoursList.length >= 2 && meanH > 0.05) {
      final varSum = hoursList.map((x) => (x - meanH) * (x - meanH)).reduce((a, b) => a + b);
      final sd = math.sqrt(varSum / hoursList.length);
      cv = sd / meanH;
    }
    final consistPts = (15 * (1 - math.min(1.0, cv / 0.35))).clamp(0.0, 15.0).toDouble();

    var rawScore = (effPts + stretchPts + awakenPts + consistPts).round().clamp(0, 100);
    final sessionCount = pool.length;
    final hasEnough = sessionCount >= 5 && curr.fold<int>(0, (a, d) => a + d.sleepTotalSeconds) > 3 * 3600;
    if (!hasEnough) {
      rawScore = math.min(rawScore, 55);
    }

    String statusKey = 'poor';
    if (rawScore >= 85) {
      statusKey = 'excellent';
    } else if (rawScore >= 70) {
      statusKey = 'good';
    } else if (rawScore >= 50) {
      statusKey = 'regular';
    }

    return AdvancedSleepReportSnapshot(
      weekMonday: monday,
      currentWeekDays: curr,
      previousWeekDays: prev,
      sleepScore: rawScore,
      statusKey: statusKey,
      sleepEfficiencyPct: effCurr,
      sleepEfficiencyPctPrev: effPrev > 0 ? effPrev : null,
      sleepOnsetMinutesAvg: onsetAvg,
      awakeningsAvgNightly: awakenAvg,
      awakeningsTotalWeek: awakenTotal,
      longestContinuousSleepSec: longest,
      idealBedtimeHour: idealH,
      idealBedtimeMinute: idealMin,
      lineSeriesSleepHours: lineHours,
      prevWeekSleepHours: prevLineHours,
      daySleepHoursWeek: dnSum <= 0 ? 0.5 : dayH,
      nightSleepHoursWeek: dnSum <= 0 ? 0.5 : nightH,
      scoreEfficiencyPoints: effPts.toDouble(),
      scoreStretchPoints: stretchPts.toDouble(),
      scoreAwakenPoints: awakenPts.toDouble(),
      scoreConsistencyPoints: consistPts,
      hasEnoughData: hasEnough,
    );
  }

  /// Etiqueta amigável para variação % (eficiência vs semana anterior).
  static double? efficiencyPctVsPrev(AdvancedSleepReportSnapshot s) {
    final p = s.sleepEfficiencyPctPrev;
    if (p == null || p <= 0) return null;
    return _pctChange(s.sleepEfficiencyPct, p);
  }
}
