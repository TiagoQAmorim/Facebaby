import 'daily_summary.dart';

/// Tendência semana a semana para uma métrica.
enum WeeklyTrendBand {
  improved,
  worse,
  stable,
  unknown,
}

/// Relatório semanal (semana ISO: segunda a domingo).
class WeeklyReportSnapshot {
  /// Segunda-feira 00:00 local da semana do [anchorDay].
  final DateTime weekMonday;

  /// Resumos diários Seg–Dom (índice 0 = segunda).
  final List<DailySummary> currentWeekDays;

  /// Semana anterior (mesma ordem).
  final List<DailySummary> previousWeekDays;

  /// Quantos dias (a partir de segunda) entram nas médias e comparações: na **semana corrente** é
  /// «até hoje»; em semanas já fechadas no passado é 7. Zero = semana futura, sem dados.
  final int aggregatedDayCount;

  final WeeklyTrendBand sleepBand;
  /// Variação % da média diária de sono (segundos) vs semana anterior.
  final double? sleepPctVsPrev;

  final WeeklyTrendBand feedingBand;
  /// Variação % da média diária de mamadas vs semana anterior.
  final double? feedingPctVsPrev;
  final double avgDailyFeedings;

  final WeeklyTrendBand diaperBand;
  /// Variação % da média diária de trocas vs semana anterior.
  final double? diaperPctVsPrev;
  final double avgDailyDiapers;

  final WeeklyTrendBand weightBand;

  /// Ganho de peso estimado na semana (último peso na semana − último antes da segunda), gramas.
  final int? weightDeltaGramsThisWeek;

  /// Variação vs ganho da semana anterior (para tendência), gramas; opcional.
  final int? weightDeltaGramsPrevWeek;

  /// Texto curto para cartão “evolução geral” (fragmento já escolhido pelo serviço: calm | active).
  final String narrativeToneKey;

  /// Destaque positivo (chave semântica para i18n).
  final String highlightKey;

  /// Dados para insights na página de detalhes.
  final List<String> patternKeys;

  /// Humores registados nas memórias (toda a semana).
  final List<String> moodSamplesWeek;

  const WeeklyReportSnapshot({
    required this.weekMonday,
    required this.currentWeekDays,
    required this.previousWeekDays,
    required this.aggregatedDayCount,
    required this.sleepBand,
    required this.sleepPctVsPrev,
    required this.feedingBand,
    required this.feedingPctVsPrev,
    required this.avgDailyFeedings,
    required this.diaperBand,
    required this.diaperPctVsPrev,
    required this.avgDailyDiapers,
    required this.weightBand,
    required this.weightDeltaGramsThisWeek,
    required this.weightDeltaGramsPrevWeek,
    required this.narrativeToneKey,
    required this.highlightKey,
    required this.patternKeys,
    required this.moodSamplesWeek,
  });
}
