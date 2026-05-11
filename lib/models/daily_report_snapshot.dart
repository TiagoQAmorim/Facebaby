import 'daily_summary.dart';

/// Dados agregados para Relatório diário + Detalhes do dia (UI).
class DailyReportSnapshot {
  final DailySummary summary;
  final DateTime calendarDay;

  /// Segundos do sono no dia anterior (comparação).
  final int yesterdaySleepSec;

  /// Variação percentual vs ontem; null se não aplicável.
  final double? sleepVsYesterdayPercent;

  final int longestSleepSessionSec;
  final DateTime? longestSleepStart;
  final DateTime? longestSleepEnd;

  /// Heurística: sessões curtas ou diurnas vs sono longo noturno.
  final int napCount;

  /// Contagem por qualidade (bad / ok / good).
  final Map<String, int> sleepQualityCounts;

  /// Segundos de sono por hora local [0..23] para gráfico.
  final List<int> sleepSecondsPerHour;

  /// Mamadas por hora do fim [0..23].
  final List<int> feedingCountPerHour;

  /// Duração média mamadas (segundos); 0 se sem dados.
  final int avgFeedingDurationSec;

  final DateTime? lastFeedingEndedAt;

  /// Humor predominante (texto livre das memórias).
  final String? predominantMood;

  /// Irritabilidade inferida: low / medium / high / unknown.
  final String irritabilityBand;

  /// 0–100 para barra «vs média da idade» (sono total).
  final int ageSleepBenchmarkPercent;

  /// above | near | below
  final String ageSleepBenchmarkBand;

  final List<DailyTimelineEntry> timeline;

  const DailyReportSnapshot({
    required this.summary,
    required this.calendarDay,
    required this.yesterdaySleepSec,
    required this.sleepVsYesterdayPercent,
    required this.longestSleepSessionSec,
    required this.longestSleepStart,
    required this.longestSleepEnd,
    required this.napCount,
    required this.sleepQualityCounts,
    required this.sleepSecondsPerHour,
    required this.feedingCountPerHour,
    required this.avgFeedingDurationSec,
    required this.lastFeedingEndedAt,
    required this.predominantMood,
    required this.irritabilityBand,
    required this.ageSleepBenchmarkPercent,
    required this.ageSleepBenchmarkBand,
    required this.timeline,
  });
}

enum DailyTimelineKind { sleep, feeding, diaper }

class DailyTimelineEntry {
  final DateTime at;
  final DailyTimelineKind kind;
  final String label;
  final String? detail;

  const DailyTimelineEntry({
    required this.at,
    required this.kind,
    required this.label,
    this.detail,
  });
}
