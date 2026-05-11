import 'daily_summary.dart';

/// Dados agregados para o relatório avançado de sono (semana ISO + semana anterior).
class AdvancedSleepReportSnapshot {
  const AdvancedSleepReportSnapshot({
    required this.weekMonday,
    required this.currentWeekDays,
    required this.previousWeekDays,
    required this.sleepScore,
    required this.statusKey,
    required this.sleepEfficiencyPct,
    this.sleepEfficiencyPctPrev,
    required this.sleepOnsetMinutesAvg,
    required this.awakeningsAvgNightly,
    required this.awakeningsTotalWeek,
    required this.longestContinuousSleepSec,
    this.idealBedtimeHour,
    this.idealBedtimeMinute,
    required this.lineSeriesSleepHours,
    required this.prevWeekSleepHours,
    required this.daySleepHoursWeek,
    required this.nightSleepHoursWeek,
    required this.scoreEfficiencyPoints,
    required this.scoreStretchPoints,
    required this.scoreAwakenPoints,
    required this.scoreConsistencyPoints,
    required this.hasEnoughData,
  });

  /// Segunda-feira da semana em análise.
  final DateTime weekMonday;

  /// Resumos diários Seg–Dom (semana atual).
  final List<DailySummary> currentWeekDays;

  /// Resumos diários Seg–Dom (semana anterior).
  final List<DailySummary> previousWeekDays;

  /// 0–100 (heurística local; sem dados → 0).
  final int sleepScore;

  /// `excellent` | `good` | `regular` | `poor`
  final String statusKey;

  /// Eficiência média (%): sono registado / intervalo entre primeiro início e último fim por dia.
  final double sleepEfficiencyPct;

  /// Mesma métrica na semana anterior (null se incomparável).
  final double? sleepEfficiencyPctPrev;

  /// “Tempo até o primeiro sono da noite” em minutos (média das noites com dados).
  final double sleepOnsetMinutesAvg;

  /// Média de despertares por noite (fragmentação na janela noite).
  final double awakeningsAvgNightly;

  /// Soma dos despertares em todas as noites da semana.
  final int awakeningsTotalWeek;

  /// Maior bloco contínuo (segundo maior `duration_sec`).
  final int longestContinuousSleepSec;

  /// Centro da janela ideal (moda/média circular dos primeiros inícios noturnos).
  final int? idealBedtimeHour;

  final int? idealBedtimeMinute;

  /// Horas de sono por dia (Seg–Dom), série para gráfico de linha.
  final List<double> lineSeriesSleepHours;

  /// Mesma série para a semana anterior (comparação barras).
  final List<double> prevWeekSleepHours;

  /// Parte diurna (06–18h) vs noturna para donut.
  final double daySleepHoursWeek;
  final double nightSleepHoursWeek;

  final double scoreEfficiencyPoints;
  final double scoreStretchPoints;
  final double scoreAwakenPoints;
  final double scoreConsistencyPoints;

  /// Poucos registos — UI deve suavizar números e mostrar aviso curto.
  final bool hasEnoughData;
}
