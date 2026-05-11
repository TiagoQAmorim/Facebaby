import 'dart:math' as math;

import '../models/baby_memory.dart';
import '../models/monthly_report_snapshot.dart';
import 'app_database.dart';

abstract final class MonthlyReportService {
  MonthlyReportService._();

  static DateTime _mondayOf(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
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

  static List<Map<String, Object?>> _filterGrowthRowsByRange(
    List<Map<String, Object?>> rows,
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    final out = <Map<String, Object?>>[];
    for (final r in rows) {
      final t = DateTime.tryParse(r['measured_at'] as String? ?? '');
      if (t == null || t.isBefore(startInclusive) || !t.isBefore(endExclusive)) continue;
      out.add(r);
    }
    out.sort((a, b) {
      final am = a['measured_at'] as String? ?? '';
      final bm = b['measured_at'] as String? ?? '';
      return am.compareTo(bm);
    });
    return out;
  }

  static Future<MonthlyReportSnapshot> load({
    required int babyId,
    required DateTime anchorInMonth,
  }) async {
    final y = anchorInMonth.year;
    final m = anchorInMonth.month;
    final monthStart = DateTime(y, m, 1);
    final monthEndExclusive = DateTime(y, m + 1, 1);
    final daysInMonth = monthEndExclusive.difference(monthStart).inDays;

    final prevMonthStart = DateTime(y, m - 1, 1);
    final prevDays = monthStart.difference(prevMonthStart).inDays;

    final db = AppDatabase.instance;

    final wRowsAll = await db.listGrowthRecords(babyId: babyId, kind: 'weight', limit: 400);
    final hRowsAll = await db.listGrowthRecords(babyId: babyId, kind: 'height', limit: 400);

    final wMonth = _filterGrowthRowsByRange(wRowsAll, monthStart, monthEndExclusive);
    final hMonth = _filterGrowthRowsByRange(hRowsAll, monthStart, monthEndExclusive);

    final weightPoints = <MonthlyGrowthPoint>[];
    for (final r in wMonth) {
      final dt = DateTime.tryParse(r['measured_at'] as String? ?? '');
      final v = (r['value'] as num?)?.toDouble();
      if (dt != null && v != null && v > 0) {
        weightPoints.add(MonthlyGrowthPoint(date: dt, value: v, isWeight: true));
      }
    }

    final heightPoints = <MonthlyGrowthPoint>[];
    for (final r in hMonth) {
      final dt = DateTime.tryParse(r['measured_at'] as String? ?? '');
      final v = (r['value'] as num?)?.toDouble();
      if (dt != null && v != null && v > 0) {
        heightPoints.add(MonthlyGrowthPoint(date: dt, value: v, isWeight: false));
      }
    }

    double? avgW;
    int? gainWG;
    if (wMonth.isNotEmpty) {
      final vals = wMonth.map((r) => (r['value'] as num).toDouble()).toList();
      avgW = _mean(vals);
      if (vals.length >= 2) {
        gainWG = ((vals.last - vals.first) * 1000).round();
      }
    }

    double? avgH;
    double? gainH;
    if (hMonth.isNotEmpty) {
      final vals = hMonth.map((r) => (r['value'] as num).toDouble()).toList();
      avgH = _mean(vals);
      if (vals.length >= 2) {
        gainH = vals.last - vals.first;
      }
    }

    var sumSleepSec = 0;
    final weekSleep = <DateTime, int>{};
    for (var i = 0; i < daysInMonth; i++) {
      final day = monthStart.add(Duration(days: i));
      final summary = await db.dailySummaryForCalendarDay(babyId: babyId, calendarDay: day);
      sumSleepSec += summary.sleepTotalSeconds;
      final mon = _mondayOf(day);
      weekSleep[mon] = (weekSleep[mon] ?? 0) + summary.sleepTotalSeconds;
    }
    final avgSleepHoursDaily = sumSleepSec / math.max(1, daysInMonth) / 3600.0;

    var prevSumSleep = 0;
    for (var i = 0; i < prevDays; i++) {
      final day = prevMonthStart.add(Duration(days: i));
      final summary = await db.dailySummaryForCalendarDay(babyId: babyId, calendarDay: day);
      prevSumSleep += summary.sleepTotalSeconds;
    }
    final prevAvgSleepDaily = prevSumSleep / math.max(1, prevDays) / 3600.0;
    final sleepPct = _pctChange(avgSleepHoursDaily, prevAvgSleepDaily);

    String sleepTrendKey = 'sleep_trend_unknown';
    if (sleepPct != null) {
      if (sleepPct > 4) {
        sleepTrendKey = 'sleep_trend_up';
      } else if (sleepPct < -4) {
        sleepTrendKey = 'sleep_trend_down';
      } else {
        sleepTrendKey = 'sleep_trend_stable';
      }
    }

    final sortedWeeks = weekSleep.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final bestWeekLabels = <String>[];
    for (var i = 0; i < sortedWeeks.length && bestWeekLabels.length < 2; i++) {
      final mon = sortedWeeks[i].key;
      final sun = mon.add(const Duration(days: 6));
      bestWeekLabels.add('${mon.day}/${mon.month}–${sun.day}/${sun.month}');
    }

    var feedTotal = 0;
    final hourTally = List<int>.filled(24, 0);
    for (var i = 0; i < daysInMonth; i++) {
      final day = monthStart.add(Duration(days: i));
      final feeds = await db.listBreastBottleFeedingsForCalendarDay(babyId: babyId, calendarDay: day);
      feedTotal += feeds.length;
      for (final f in feeds) {
        final end = DateTime.tryParse(f['ended_at'] as String? ?? '');
        if (end != null) hourTally[end.hour]++;
      }
    }
    final avgFeedsPerDay = feedTotal / math.max(1, daysInMonth);

    final hourIndexed = List.generate(24, (h) => h);
    hourIndexed.sort((a, b) => hourTally[b].compareTo(hourTally[a]));
    final topFeedingHours = hourIndexed.where((h) => hourTally[h] > 0).take(3).toList();

    final milestones = <MonthlyMilestone>[];

    final vaccines = await db.listVaccines(babyId: babyId);
    for (final v in vaccines) {
      final applied = DateTime.tryParse(v['applied_at'] as String? ?? '');
      if (applied == null || applied.isBefore(monthStart) || !applied.isBefore(monthEndExclusive)) continue;
      final name = (v['name'] as String?)?.trim() ?? '—';
      final dose = (v['dose'] as String?)?.trim();
      final title = dose == null || dose.isEmpty ? name : '$name ($dose)';
      milestones.add(MonthlyMilestone(date: applied, title: title, source: MonthlyMilestoneSource.vaccine));
    }

    final consults = await db.listConsultations(babyId: babyId);
    for (final c in consults) {
      final oc = DateTime.tryParse(c['occurred_at'] as String? ?? '');
      if (oc == null || oc.isBefore(monthStart) || !oc.isBefore(monthEndExclusive)) continue;
      final titleRaw = (c['title'] as String?)?.trim() ?? '';
      milestones.add(MonthlyMilestone(date: oc, title: titleRaw, source: MonthlyMilestoneSource.consultation));
    }

    final memRows = await db.listMemoriesInDateRange(
      babyId: babyId,
      startInclusive: monthStart,
      endExclusive: monthEndExclusive,
    );
    for (final row in memRows) {
      try {
        final bm = BabyMemory.fromRow(row);
        if (bm.badgeId.isNotEmpty) {
          milestones.add(MonthlyMilestone(
            date: bm.memoryDate,
            title: bm.title,
            source: MonthlyMilestoneSource.memory,
            badgeId: bm.badgeId.trim().isEmpty ? null : bm.badgeId.trim(),
          ));
        }
      } catch (_) {}
    }

    milestones.sort((a, b) => a.date.compareTo(b.date));
    final milestonesOut = milestones.length > 15 ? milestones.sublist(0, 15) : milestones;

    final memoriesWithPhoto = <BabyMemory>[];
    for (final row in memRows.reversed) {
      try {
        final bm = BabyMemory.fromRow(row);
        final hasPic = (bm.photoB64 != null && bm.photoB64!.isNotEmpty) ||
            (bm.photoUrl != null && bm.photoUrl!.trim().isNotEmpty);
        if (hasPic) memoriesWithPhoto.add(bm);
      } catch (_) {}
      if (memoriesWithPhoto.length >= 16) break;
    }

    return MonthlyReportSnapshot(
      year: y,
      month: m,
      weightPoints: weightPoints,
      heightPoints: heightPoints,
      avgWeightKg: avgW,
      weightGainGrams: gainWG,
      avgHeightCm: avgH,
      heightGainCm: gainH,
      avgSleepHoursDaily: avgSleepHoursDaily,
      sleepTrendVsPrevMonthPct: sleepPct,
      sleepTrendKey: sleepTrendKey,
      bestWeekLabels: bestWeekLabels,
      avgFeedsPerDay: avgFeedsPerDay,
      topFeedingHours: topFeedingHours,
      milestones: milestonesOut,
      memoriesWithPhoto: memoriesWithPhoto,
    );
  }
}
