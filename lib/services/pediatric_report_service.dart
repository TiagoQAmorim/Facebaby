import 'dart:math' as math;

import '../models/daily_summary.dart';
import '../models/pediatric_report_snapshot.dart';
import '../models/symptom_report.dart';
import 'app_database.dart';

/// Agrega dados locais para o relatório pediátrico num intervalo de dias civis
/// [[periodStart], [periodEndInclusive]].
abstract final class PediatricReportService {
  PediatricReportService._();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime? _parse(String? iso) => DateTime.tryParse(iso ?? '');

  static double _mean(Iterable<double> xs) {
    final list = xs.toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  static Future<List<Map<String, Object?>>> _sleepRowsForPeriod({
    required int babyId,
    required DateTime periodStart,
    required DateTime periodEndInclusive,
  }) async {
    final poolStart = periodStart.subtract(const Duration(days: 1));
    final poolEnd = periodEndInclusive.add(const Duration(days: 1));
    final db = AppDatabase.instance;
    final byId = <int, Map<String, Object?>>{};
    var cursor = DateTime(poolStart.year, poolStart.month, poolStart.day);
    final end = DateTime(poolEnd.year, poolEnd.month, poolEnd.day);
    while (!cursor.isAfter(end)) {
      final rows = await db.listSleepRecordsForCalendarDay(babyId: babyId, calendarDay: cursor);
      for (final r in rows) {
        final id = (r['id'] as num?)?.toInt();
        if (id != null && id > 0) byId[id] = r;
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

  static (DateTime start, DateTime end) _nightWindowEnding(DateTime day) {
    final d0 = DateTime(day.year, day.month, day.day);
    final prev = d0.subtract(const Duration(days: 1));
    final start = DateTime(prev.year, prev.month, prev.day, 18, 0);
    final end = DateTime(day.year, day.month, day.day, 10, 0);
    return (start, end);
  }

  static double _avgNightAwakeningsForPeriod(
    List<Map<String, Object?>> pool,
    DateTime periodStart,
    int dayCount,
  ) {
    final perNight = <double>[];
    for (var i = 0; i < dayCount; i++) {
      final day = periodStart.add(Duration(days: i));
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
      perNight.add(math.max(0, overlapping.length - 1).toDouble());
    }
    return perNight.isEmpty ? 0 : _mean(perNight);
  }

  static int _longestSleepSec(List<Map<String, Object?>> pool) {
    var longest = 0;
    for (final r in pool) {
      final d = (r['duration_sec'] as num?)?.toInt() ?? 0;
      if (d > longest) longest = d;
    }
    return longest;
  }

  static String _sleepPatternKey(double awakenAvg, int longestSec) {
    final longestH = longestSec / 3600.0;
    if (awakenAvg <= 1.8 && longestH >= 3.2) return 'stable';
    if (awakenAvg >= 3.5 || longestH < 2.0) return 'fragmented';
    return 'moderate';
  }

  static String _feedingKind(String? raw) {
    final t = (raw ?? '').trim().toLowerCase();
    if (t.contains('solid') || t == 'solidos' || t.contains('pap')) return 'solid';
    if (t.contains('mamadeira') || t.contains('formula') || t.contains('fórmula')) return 'formula';
    if (t.contains('peito') || t.contains('breast') || t.contains('mama')) return 'breast';
    if (t.isEmpty) return 'breast';
    return 'other';
  }

  static String _irritabilityFromMoods(List<String> moods) {
    if (moods.isEmpty) return 'unknown';
    final buf = StringBuffer();
    for (final m in moods) {
      buf.write(m.toLowerCase());
      buf.write(' ');
    }
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
        s.contains('feliz')) {
      return 'low';
    }
    return 'medium';
  }

  static bool _journalMentions(String? text, List<String> keys) {
    if (text == null || text.trim().isEmpty) return false;
    final lower = text.toLowerCase();
    for (final k in keys) {
      if (lower.contains(k)) return true;
    }
    return false;
  }

  /// Limite máximo de dias num relatório (evita consultas excessivas).
  static const int maxPeriodDays = 366;

  static Future<PediatricReportSnapshot> load({
    required int babyId,
    required DateTime periodStart,
    required DateTime periodEndInclusive,
  }) async {
    var start = _dateOnly(periodStart);
    var end = _dateOnly(periodEndInclusive);
    if (end.isBefore(start)) {
      final t = start;
      start = end;
      end = t;
    }
    var spanDays = end.difference(start).inDays + 1;
    if (spanDays > maxPeriodDays) {
      end = start.add(Duration(days: maxPeriodDays - 1));
      spanDays = maxPeriodDays;
    }

    final periodEndExclusive = end.add(const Duration(days: 1));

    final db = AppDatabase.instance;

    final summaries = <DailySummary>[];
    for (var cursor = start; !cursor.isAfter(end); cursor = cursor.add(const Duration(days: 1))) {
      summaries.add(await db.dailySummaryForHomePicker(babyId: babyId, calendarDay: cursor));
    }

    final avgFeed = _mean(summaries.map((e) => e.feedings.toDouble()));
    final avgSleepH = _mean(summaries.map((e) => e.sleepTotalSeconds / 3600.0));
    final avgDiaper = _mean(summaries.map((e) => e.diapers.toDouble()));

    final wRows = await db.listGrowthRecords(babyId: babyId, kind: 'weight', limit: 400);
    final weightsInPeriod = <Map<String, Object?>>[];
    for (final r in wRows) {
      final t = DateTime.tryParse(r['measured_at'] as String? ?? '');
      final v = (r['value'] as num?)?.toDouble();
      if (t == null || v == null || v <= 0) continue;
      if (t.isBefore(start) || !t.isBefore(periodEndExclusive)) continue;
      weightsInPeriod.add(r);
    }
    weightsInPeriod.sort((a, b) {
      final am = a['measured_at'] as String? ?? '';
      final bm = b['measured_at'] as String? ?? '';
      return am.compareTo(bm);
    });
    double? wStart;
    double? wEnd;
    int? wDeltaG;
    if (weightsInPeriod.isNotEmpty) {
      wStart = (weightsInPeriod.first['value'] as num).toDouble();
      wEnd = (weightsInPeriod.last['value'] as num).toDouble();
      wDeltaG = ((wEnd - wStart) * 1000).round();
    }

    double? heightCm;
    final hRows = await db.listGrowthRecords(babyId: babyId, kind: 'height', limit: 400);
    DateTime? bestT;
    for (final r in hRows) {
      final t = DateTime.tryParse(r['measured_at'] as String? ?? '');
      final v = (r['value'] as num?)?.toDouble();
      if (t == null || v == null || v <= 0) continue;
      if (t.isBefore(start) || !t.isBefore(periodEndExclusive)) continue;
      if (bestT == null || t.isAfter(bestT)) {
        bestT = t;
        heightCm = v;
      }
    }

    final sleepPool = await _sleepRowsForPeriod(
      babyId: babyId,
      periodStart: start,
      periodEndInclusive: end,
    );
    final awakenAvg = _avgNightAwakeningsForPeriod(sleepPool, start, spanDays);
    final longestSec = _longestSleepSec(sleepPool);
    final sleepPat = _sleepPatternKey(awakenAvg, longestSec);

    final feedRows = await db.listFeedings(babyId: babyId, limit: 600, startedSince: start.subtract(const Duration(days: 1)));
    final feedsPeriod = <Map<String, Object?>>[];
    for (final r in feedRows) {
      final endAt = _parse(r['ended_at'] as String?);
      if (endAt == null || endAt.isBefore(start) || !endAt.isBefore(periodEndExclusive)) continue;
      feedsPeriod.add(r);
    }

    var breastN = 0, formulaN = 0, solidN = 0;
    var breastDur = 0, formulaDur = 0, solidDur = 0;
    final medHints = <String>{};

    for (final r in feedsPeriod) {
      final kind = _feedingKind(r['type'] as String?);
      final dur = (r['duration_sec'] as num?)?.toInt() ?? 0;
      final note = (r['note'] as String?) ?? '';
      if (_journalMentions(note, ['dipirona', 'paracetamol', 'ibuprofeno', 'medica', 'antibiótico', 'antibiotico'])) {
        medHints.add(note.trim());
      }
      switch (kind) {
        case 'breast':
        case 'other':
          breastN++;
          breastDur += dur;
          break;
        case 'formula':
          formulaN++;
          formulaDur += dur;
          break;
        case 'solid':
          solidN++;
          solidDur += dur;
          break;
      }
    }

    double? avgBmin = breastN > 0 ? breastDur / breastN / 60.0 : null;
    double? avgFmin = formulaN > 0 ? formulaDur / formulaN / 60.0 : null;
    double? avgSmin = solidN > 0 ? solidDur / solidN / 60.0 : null;

    final moods = <String>[];
    for (var cursor = start; !cursor.isAfter(end); cursor = cursor.add(const Duration(days: 1))) {
      moods.addAll(await db.listMemoryMoodsForCalendarDay(babyId: babyId, calendarDay: cursor));
    }
    final irrit = _irritabilityFromMoods(moods);

    var reflux = false;
    var colic = false;
    for (var cursor = start; !cursor.isAfter(end); cursor = cursor.add(const Duration(days: 1))) {
      final j = await db.getDailyJournalText(babyId: babyId, calendarDay: cursor);
      if (_journalMentions(j, ['reflux', 'refluxo', 'regurg'])) reflux = true;
      if (_journalMentions(j, ['cólica', 'colica', 'colic', 'cólic'])) colic = true;
    }

    final symptomRows = await db.listSymptomReportsInPeriod(
      babyId: babyId,
      periodStart: start,
      periodEndInclusive: end,
    );
    final symptomReportsInPeriod = symptomRows.map(SymptomReport.fromMap).toList();
    var feverEpisodesLogged = 0;
    var cryingNotedInSymptomReports = false;
    var painNotedInSymptomReports = false;
    for (final sr in symptomReportsInPeriod) {
      if (sr.fever) feverEpisodesLogged++;
      if (sr.unexplainedCrying) cryingNotedInSymptomReports = true;
      if (sr.pain) painNotedInSymptomReports = true;
      if (sr.reflux) reflux = true;
      if (sr.colic) colic = true;
      final medNote = sr.medicationNote?.trim();
      if (medNote != null && medNote.isNotEmpty) medHints.add(medNote);
    }

    final vaccinesRaw = await db.listVaccines(babyId: babyId);
    final vaccineLines = <String>[];
    for (final v in vaccinesRaw) {
      final applied = _parse(v['applied_at'] as String?);
      if (applied == null || applied.isBefore(start) || !applied.isBefore(periodEndExclusive)) continue;
      final name = (v['name'] as String?)?.trim() ?? '';
      final dose = (v['dose'] as String?)?.trim() ?? '';
      final line = dose.isEmpty ? name : '$name ($dose)';
      if (line.isNotEmpty) {
        try {
          final dlab = '${applied.day.toString().padLeft(2, '0')}/${applied.month.toString().padLeft(2, '0')}/${applied.year}';
          vaccineLines.add('$line — $dlab');
        } catch (_) {
          vaccineLines.add(line);
        }
      }
    }

    return PediatricReportSnapshot(
      periodStart: start,
      periodEndInclusive: end,
      avgFeedingsPerDay: avgFeed,
      avgSleepHoursPerDay: avgSleepH,
      avgDiapersPerDay: avgDiaper,
      weightStartKg: wStart,
      weightEndKg: wEnd,
      weightDeltaGrams: wDeltaG,
      heightCm: heightCm,
      sleepAwakeningsAvg: awakenAvg,
      longestSleepSec: longestSec,
      sleepPatternKey: sleepPat,
      breastfeedingSessions: breastN,
      formulaSessions: formulaN,
      solidFoodSessions: solidN,
      avgBreastMinutes: avgBmin,
      avgFormulaMinutes: avgFmin,
      avgSolidMinutes: avgSmin,
      feverEpisodesLogged: feverEpisodesLogged,
      refluxMentionedInJournals: reflux,
      colicMentionedInJournals: colic,
      irritabilityKey: irrit,
      vaccinesInPeriodLines: vaccineLines,
      customMedicationHints: medHints.take(6).toList(),
      symptomReportsInPeriod: symptomReportsInPeriod,
      cryingNotedInSymptomReports: cryingNotedInSymptomReports,
      painNotedInSymptomReports: painNotedInSymptomReports,
    );
  }
}
