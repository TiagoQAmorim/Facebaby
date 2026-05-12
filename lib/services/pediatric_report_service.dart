import 'dart:math' as math;

import '../models/daily_summary.dart';
import '../models/pediatric_report_snapshot.dart';
import '../models/pediatric_symptom_occurrence.dart';
import '../models/symptom_report.dart';
import '../utils/measurement_format.dart';
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

  static bool _journalMentions(String? text, List<String> keys) {
    if (text == null || text.trim().isEmpty) return false;
    final lower = text.toLowerCase();
    for (final k in keys) {
      if (lower.contains(k)) return true;
    }
    return false;
  }

  static DateTime? _appliedAtLocalFromRow(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final dt = DateTime.tryParse(s);
    if (dt == null) return null;
    return dt.isUtc ? dt.toLocal() : dt;
  }

  static bool _hasStructuredSymptomOnCalendarDay(
    List<PediatricSymptomOccurrence> list,
    DateTime calendarDay,
  ) {
    final y = calendarDay.year;
    final m = calendarDay.month;
    final d = calendarDay.day;
    for (final o in list) {
      if (o.journalDayOnly) continue;
      final t = o.at;
      if (t.year == y && t.month == m && t.day == d) return true;
    }
    return false;
  }

  static void _sortSymptomOccurrences(Map<String, List<PediatricSymptomOccurrence>> byKind) {
    for (final list in byKind.values) {
      list.sort((a, b) => a.at.compareTo(b.at));
    }
  }

  /// Último registo de crescimento que satisfaz [include] (`measured_at` mais recente).
  static Map<String, Object?>? _latestGrowthRecordWhere(
    List<Map<String, Object?>> rows,
    bool Function(DateTime t) include,
  ) {
    Map<String, Object?>? best;
    DateTime? bestT;
    for (final r in rows) {
      final t = DateTime.tryParse(r['measured_at'] as String? ?? '');
      final v = (r['value'] as num?)?.toDouble();
      if (t == null || v == null || v <= 0) continue;
      if (!include(t)) continue;
      if (bestT == null || t.isAfter(bestT)) {
        bestT = t;
        best = r;
      }
    }
    return best;
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
    } else {
      // Sem pesagens no intervalo: usar o último peso conhecido até ao fim do período e,
      // para a variação, o último antes do início do período (se existir).
      final latestUpToEnd = _latestGrowthRecordWhere(
        wRows,
        (t) => t.isBefore(periodEndExclusive),
      );
      if (latestUpToEnd != null) {
        wEnd = (latestUpToEnd['value'] as num).toDouble();
      }
      final latestBeforeStart = _latestGrowthRecordWhere(wRows, (t) => t.isBefore(start));
      if (latestBeforeStart != null) {
        wStart = (latestBeforeStart['value'] as num).toDouble();
      }
      if (wStart != null && wEnd != null) {
        wDeltaG = ((wEnd - wStart) * 1000).round();
      } else {
        wDeltaG = null;
      }
    }

    double? heightCm;
    final hRows = await db.listGrowthRecords(babyId: babyId, kind: 'height', limit: 400);
    final heightInPeriod = _latestGrowthRecordWhere(
      hRows,
      (t) => !t.isBefore(start) && t.isBefore(periodEndExclusive),
    );
    if (heightInPeriod != null) {
      heightCm = (heightInPeriod['value'] as num).toDouble();
    } else {
      final latestH = _latestGrowthRecordWhere(
        hRows,
        (t) => t.isBefore(periodEndExclusive),
      );
      if (latestH != null) {
        heightCm = (latestH['value'] as num).toDouble();
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
    final hasSleepPatternBasis = sleepPool.isNotEmpty;

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

    final symptomRows = await db.listSymptomReportsInPeriod(
      babyId: babyId,
      periodStart: start,
      periodEndInclusive: end,
    );
    final symptomReportsInPeriod = symptomRows.map(SymptomReport.fromMap).toList();

    final byKind = <String, List<PediatricSymptomOccurrence>>{
      'reflux': [],
      'colic': [],
      'crying': [],
      'pain': [],
      'fever': [],
      'medication': [],
      'other': [],
    };

    for (final sr in symptomReportsInPeriod) {
      final t = sr.occurredAt;
      if (sr.reflux) byKind['reflux']!.add(PediatricSymptomOccurrence(at: t));
      if (sr.colic) byKind['colic']!.add(PediatricSymptomOccurrence(at: t));
      if (sr.unexplainedCrying) byKind['crying']!.add(PediatricSymptomOccurrence(at: t));
      if (sr.pain) byKind['pain']!.add(PediatricSymptomOccurrence(at: t));
      if (sr.fever) {
        final tempStr = sr.tempCelsius != null ? MeasurementFormat.temperature(sr.tempCelsius) : null;
        byKind['fever']!.add(PediatricSymptomOccurrence(at: t, detail: tempStr));
      }
      final medNote = sr.medicationNote?.trim();
      if (medNote != null && medNote.isNotEmpty) {
        medHints.add(medNote);
        byKind['medication']!.add(PediatricSymptomOccurrence(at: t, detail: medNote));
      }
      final other = sr.otherNote?.trim();
      if (other != null && other.isNotEmpty) {
        byKind['other']!.add(PediatricSymptomOccurrence(at: t, detail: other));
      }
    }

    for (var cursor = start; !cursor.isAfter(end); cursor = cursor.add(const Duration(days: 1))) {
      final j = await db.getDailyJournalText(babyId: babyId, calendarDay: cursor);
      if (_journalMentions(j, ['reflux', 'refluxo', 'regurg']) &&
          !_hasStructuredSymptomOnCalendarDay(byKind['reflux']!, cursor)) {
        byKind['reflux']!.add(
          PediatricSymptomOccurrence(
            at: DateTime(cursor.year, cursor.month, cursor.day),
            journalDayOnly: true,
          ),
        );
      }
      if (_journalMentions(j, ['cólica', 'colica', 'colic', 'cólic']) &&
          !_hasStructuredSymptomOnCalendarDay(byKind['colic']!, cursor)) {
        byKind['colic']!.add(
          PediatricSymptomOccurrence(
            at: DateTime(cursor.year, cursor.month, cursor.day),
            journalDayOnly: true,
          ),
        );
      }
    }
    _sortSymptomOccurrences(byKind);

    final vaccinesRaw = await db.listVaccines(babyId: babyId);
    final vaccineLines = <String>[];
    for (final v in vaccinesRaw) {
      final appliedInst = _appliedAtLocalFromRow(v['applied_at']);
      if (appliedInst == null) continue;
      final appliedDay = DateTime(appliedInst.year, appliedInst.month, appliedInst.day);
      if (appliedDay.isBefore(start) || appliedDay.isAfter(end)) continue;
      final name = (v['name'] as String?)?.trim() ?? '';
      final dose = (v['dose'] as String?)?.trim() ?? '';
      final line = dose.isEmpty ? name : '$name ($dose)';
      if (line.isNotEmpty) {
        try {
          final dlab =
              '${appliedDay.day.toString().padLeft(2, '0')}/${appliedDay.month.toString().padLeft(2, '0')}/${appliedDay.year}';
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
      hasSleepPatternBasis: hasSleepPatternBasis,
      breastfeedingSessions: breastN,
      formulaSessions: formulaN,
      solidFoodSessions: solidN,
      avgBreastMinutes: avgBmin,
      avgFormulaMinutes: avgFmin,
      avgSolidMinutes: avgSmin,
      vaccinesInPeriodLines: vaccineLines,
      customMedicationHints: medHints.take(6).toList(),
      symptomOccurrencesByKind: byKind,
    );
  }
}
