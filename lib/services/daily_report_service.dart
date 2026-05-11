import 'dart:math' as math;

import '../models/daily_report_snapshot.dart';
import 'app_database.dart';
import 'sleep_routine.dart';

/// Agrega dados locais (SQLite / web) para o relatório diário.
abstract final class DailyReportService {
  DailyReportService._();

  static double _expectedTotalSleepHoursMid(int monthsOld) {
    if (monthsOld <= 3) return 15.5;
    if (monthsOld <= 6) return 14.5;
    if (monthsOld <= 12) return 13.0;
    if (monthsOld <= 24) return 12.5;
    return 11.5;
  }

  static void _addIntervalToHourBuckets(
    DateTime dayStart,
    DateTime dayEnd,
    DateTime segStart,
    DateTime segEnd,
    List<int> buckets,
  ) {
    var cur = segStart.isBefore(dayStart) ? dayStart : segStart;
    final last = segEnd.isAfter(dayEnd) ? dayEnd : segEnd;
    while (cur.isBefore(last)) {
      final hour = cur.hour;
      final nextHour = DateTime(cur.year, cur.month, cur.day, cur.hour + 1);
      final chunkEnd = nextHour.isBefore(last) ? nextHour : last;
      buckets[hour] += chunkEnd.difference(cur).inSeconds;
      cur = chunkEnd;
    }
  }

  static String _irritabilityFromMoods(List<String> moods, String? predominant) {
    if (moods.isEmpty) return 'unknown';
    final buf = StringBuffer();
    for (final m in moods) {
      buf.write(m.toLowerCase());
      buf.write(' ');
    }
    if (predominant != null) buf.write(predominant.toLowerCase());
    final s = buf.toString();
    if (s.contains('irrit') ||
        s.contains('chor') ||
        s.contains('nervos') ||
        s.contains('agit') ||
        s.contains('fuss') ||
        s.contains('cry')) {
      return 'high';
    }
    if (s.contains('calm') ||
        s.contains('calmo') ||
        s.contains('tranquil') ||
        s.contains('happy') ||
        s.contains('feliz') ||
        s.contains('ótimo') ||
        s.contains('otimo')) {
      return 'low';
    }
    return 'medium';
  }

  static Future<DailyReportSnapshot> load({
    required int babyId,
    required DateTime calendarDay,
  }) async {
    final db = AppDatabase.instance;
    final day = DateTime(calendarDay.year, calendarDay.month, calendarDay.day);
    final yesterday = day.subtract(const Duration(days: 1));

    final summary = await db.dailySummaryForHomePicker(babyId: babyId, calendarDay: day);
    final prev = await db.dailySummaryForHomePicker(babyId: babyId, calendarDay: yesterday);

    final sleeps = await db.listSleepRecordsForCalendarDay(babyId: babyId, calendarDay: day);
    final feeds = await db.listBreastBottleFeedingsForCalendarDay(babyId: babyId, calendarDay: day);
    final diapers = await db.listDiapersForCalendarDay(babyId: babyId, calendarDay: day);
    final moodSamples = await db.listMemoryMoodsForCalendarDay(babyId: babyId, calendarDay: day);

    final dayStart = day;
    final dayEnd = day.add(const Duration(days: 1));
    final buckets = List<int>.filled(24, 0);
    final qualityCounts = <String, int>{'bad': 0, 'ok': 0, 'good': 0};

    var longestSec = 0;
    DateTime? longestStart;
    DateTime? longestEnd;

    for (final r in sleeps) {
      final started = DateTime.tryParse(r['started_at'] as String? ?? '');
      final ended = DateTime.tryParse(r['ended_at'] as String? ?? '');
      final sec = (r['duration_sec'] as num?)?.toInt() ?? 0;
      if (started != null && ended != null && sec > longestSec) {
        longestSec = sec;
        longestStart = started;
        longestEnd = ended;
      }
      if (started != null && ended != null) {
        _addIntervalToHourBuckets(dayStart, dayEnd, started, ended, buckets);
      }
      final q = (r['quality'] as String?)?.trim().toLowerCase() ?? 'good';
      if (q == 'bad' || q == 'ok' || q == 'good') {
        qualityCounts[q] = (qualityCounts[q] ?? 0) + 1;
      } else {
        qualityCounts['good'] = (qualityCounts['good'] ?? 0) + 1;
      }
    }

    var napCount = 0;
    if (sleeps.isNotEmpty) {
      if (sleeps.length == 1) {
        // Uma única sessão no dia = 1 (antes ficava 0 por erro).
        napCount = 1;
      } else {
        final durations = sleeps.map((r) => (r['duration_sec'] as num?)?.toInt() ?? 0).toList();
        final maxSec = durations.reduce(math.max);
        if (maxSec >= 3 * 3600) {
          napCount = sleeps.length - 1;
        } else {
          napCount = sleeps.length;
        }
      }
    }

    double? vsY;
    if (prev.sleepTotalSeconds > 0) {
      vsY = (summary.sleepTotalSeconds - prev.sleepTotalSeconds) / prev.sleepTotalSeconds * 100.0;
    }

    final feedBuckets = List<int>.filled(24, 0);
    var feedDurSum = 0;
    DateTime? lastFeedEnd;
    for (final f in feeds) {
      final dur = (f['duration_sec'] as num?)?.toInt() ?? 0;
      feedDurSum += dur;
      final end = DateTime.tryParse(f['ended_at'] as String? ?? '');
      if (end != null) {
        feedBuckets[end.hour]++;
        if (lastFeedEnd == null || end.isAfter(lastFeedEnd)) lastFeedEnd = end;
      }
    }
    final avgFeedSec = feeds.isEmpty ? 0 : feedDurSum ~/ feeds.length;

    String? predominant;
    if (moodSamples.isNotEmpty) {
      final tally = <String, int>{};
      for (final m in moodSamples) {
        final k = m.trim();
        if (k.isEmpty) continue;
        tally[k] = (tally[k] ?? 0) + 1;
      }
      var best = 0;
      for (final e in tally.entries) {
        if (e.value > best) {
          best = e.value;
          predominant = e.key;
        }
      }
    }

    final irritability = _irritabilityFromMoods(moodSamples, predominant);

    final baby = await db.getBabyById(babyId);
    final birthRaw = baby?['birth_date'] as String?;
    final birth = DateTime.tryParse(birthRaw ?? '');
    final monthsOld = SleepRoutine.monthsOld(birth);
    final expectedH = _expectedTotalSleepHoursMid(monthsOld);
    final actualH = summary.sleepTotalSeconds / 3600.0;
    final ratio = expectedH <= 0 ? 0.0 : (actualH / expectedH).clamp(0.0, 1.35);
    final benchmarkPct = (ratio / 1.35 * 100).round().clamp(0, 100);
    var band = 'near';
    if (ratio >= 1.05) {
      band = 'above';
    } else if (ratio <= 0.85) {
      band = 'below';
    }

    final timeline = <DailyTimelineEntry>[];
    for (final r in sleeps) {
      final end = DateTime.tryParse(r['ended_at'] as String? ?? '');
      final sec = (r['duration_sec'] as num?)?.toInt() ?? 0;
      if (end != null) {
        timeline.add(
          DailyTimelineEntry(
            at: end,
            kind: DailyTimelineKind.sleep,
            label: 'sleep',
            detail: formatDurationShort(sec),
          ),
        );
      }
    }
    for (final f in feeds) {
      final end = DateTime.tryParse(f['ended_at'] as String? ?? '');
      if (end != null) {
        timeline.add(DailyTimelineEntry(at: end, kind: DailyTimelineKind.feeding, label: 'feeding'));
      }
    }
    for (final d in diapers) {
      final ch = DateTime.tryParse(d['changed_at'] as String? ?? '');
      if (ch != null) {
        final k = (d['kind'] as String?)?.trim().toLowerCase() ?? '';
        timeline.add(
          DailyTimelineEntry(
            at: ch,
            kind: DailyTimelineKind.diaper,
            label: 'diaper',
            detail: k,
          ),
        );
      }
    }
    timeline.sort((a, b) => a.at.compareTo(b.at));

    return DailyReportSnapshot(
      summary: summary,
      calendarDay: day,
      yesterdaySleepSec: prev.sleepTotalSeconds,
      sleepVsYesterdayPercent: vsY,
      longestSleepSessionSec: longestSec,
      longestSleepStart: longestStart,
      longestSleepEnd: longestEnd,
      napCount: napCount,
      sleepQualityCounts: qualityCounts,
      sleepSecondsPerHour: buckets,
      feedingCountPerHour: feedBuckets,
      avgFeedingDurationSec: avgFeedSec,
      lastFeedingEndedAt: lastFeedEnd,
      predominantMood: predominant,
      irritabilityBand: irritability,
      ageSleepBenchmarkPercent: benchmarkPct,
      ageSleepBenchmarkBand: band,
      timeline: timeline,
    );
  }

  static String formatDurationShort(int totalSec) {
    if (totalSec <= 0) return '0m';
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m';
  }
}

String formatTimeHm(DateTime? dt) {
  if (dt == null) return '—';
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
