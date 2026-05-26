import '../../i18n/app_i18n.dart';
import '../../models/daily_summary.dart';
import '../app_database.dart';
import '../home_yesterday_baba_service.dart';

/// Gera insights sem OpenAI — padrões simples nos registros locais.
abstract final class AiInsightLocalEngine {
  AiInsightLocalEngine._();

  static Future<String> buildDailySummary({
    required int babyId,
    required String babyName,
    required String? babySex,
    required DateTime? birthDate,
    required S strings,
  }) async {
    final yesterday = _dateOnly(DateTime.now().subtract(const Duration(days: 1)));
    final dayBefore =
        _dateOnly(DateTime.now().subtract(const Duration(days: 2)));

    await AppDatabase.instance.ensureYesterdayDailySummarySnapshot(
      babyId: babyId,
    );

    final y = await AppDatabase.instance.dailySummaryForHomePicker(
      babyId: babyId,
      calendarDay: yesterday,
    );
    final prev = await AppDatabase.instance.dailySummaryForHomePicker(
      babyId: babyId,
      calendarDay: dayBefore,
    );

    final name = babyName.trim().isEmpty ? strings.baby : babyName.trim();

    if (_isEmpty(y) && _isEmpty(prev)) {
      return strings.homeAiInsightDailyQuiet(name);
    }

    final sleepBetter = y.sleepTotalSeconds > 0 &&
        prev.sleepTotalSeconds > 0 &&
        y.sleepTotalSeconds >= prev.sleepTotalSeconds + 1800;
    final sleepLess = y.sleepTotalSeconds > 0 &&
        prev.sleepTotalSeconds > 0 &&
        y.sleepTotalSeconds <= prev.sleepTotalSeconds - 1800;

    if (sleepBetter) {
      return strings.homeAiInsightDailySleepBetter(name);
    }
    if (sleepLess) {
      return strings.homeAiInsightDailySleepLess(name);
    }

    if (y.feedings > prev.feedings + 1 && y.feedings >= 2) {
      return strings.homeAiInsightDailyFeedingBetter(name);
    }

    if (!_isEmpty(y) &&
        (y.sleepSessions >= prev.sleepSessions || y.diapers >= prev.diapers)) {
      return strings.homeAiInsightDailyPeaceful(name);
    }

    final growthBit = await _shortGrowthHint(
      strings: strings,
      babyId: babyId,
      babySex: babySex,
      birthDate: birthDate,
    );
    if (growthBit != null) {
      return strings.homeAiInsightDailyWithGrowth(name, growthBit);
    }

    return strings.homeAiInsightDailyDefault(name);
  }

  static Future<String> buildWeeklySummary({
    required int babyId,
    required String babyName,
    required S strings,
  }) async {
    final name = babyName.trim().isEmpty ? strings.baby : babyName.trim();
    final now = _dateOnly(DateTime.now());
    var sleepRecent = 0;
    var sleepPrev = 0;
    var feedRecent = 0;
    var feedPrev = 0;
    var daysWithData = 0;

    for (var i = 1; i <= 7; i++) {
      final d = now.subtract(Duration(days: i));
      final s = await AppDatabase.instance.dailySummaryForHomePicker(
        babyId: babyId,
        calendarDay: d,
      );
      if (!_isEmpty(s)) daysWithData++;
      sleepRecent += s.sleepTotalSeconds;
      feedRecent += s.feedings;
    }
    for (var i = 8; i <= 14; i++) {
      final d = now.subtract(Duration(days: i));
      final s = await AppDatabase.instance.dailySummaryForHomePicker(
        babyId: babyId,
        calendarDay: d,
      );
      sleepPrev += s.sleepTotalSeconds;
      feedPrev += s.feedings;
    }

    if (daysWithData < 2) {
      return strings.homeAiInsightWeeklyFewData(name);
    }

    if (sleepRecent > sleepPrev + 3600 && sleepPrev > 0) {
      return strings.homeAiInsightWeeklySleepImproved(name);
    }
    if (feedRecent > feedPrev + 3 && feedPrev > 0) {
      return strings.homeAiInsightWeeklyFeedingImproved(name);
    }

    return strings.homeAiInsightWeeklyStable(name);
  }

  static Future<String?> _shortGrowthHint({
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
    if (full.contains(strings.homeYesterdayBabaGrowthBothWithin)) {
      return strings.homeAiInsightGrowthShortHealthy;
    }
    if (full.contains(strings.homeYesterdayBabaGrowthBelow) ||
        full.contains(strings.homeYesterdayBabaBandBelow)) {
      return strings.homeAiInsightGrowthShortWatch;
    }
    return null;
  }

  static bool _isEmpty(DailySummary s) =>
      s.feedings == 0 &&
      s.diapers == 0 &&
      s.sleepTotalSeconds == 0 &&
      s.sleepSessions == 0;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// Segunda-feira da semana (id estável `yyyyMMdd`).
String aiInsightWeekDocId(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  final monday = local.subtract(Duration(days: local.weekday - DateTime.monday));
  final y = monday.year.toString().padLeft(4, '0');
  final m = monday.month.toString().padLeft(2, '0');
  final d = monday.day.toString().padLeft(2, '0');
  return '$y$m$d';
}

String aiInsightDayDocId(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y$m$day';
}
