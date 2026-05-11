import 'baby_memory.dart';

/// Ponto para gráfico de crescimento no mês.
class MonthlyGrowthPoint {
  final DateTime date;
  /// Peso em kg ou altura em cm conforme [isWeight].
  final double value;
  final bool isWeight;

  const MonthlyGrowthPoint({
    required this.date,
    required this.value,
    required this.isWeight,
  });
}

enum MonthlyMilestoneSource {
  vaccine,
  consultation,
  memory,
}

/// Marco do mês (vacina, consulta, memória especial).
class MonthlyMilestone {
  final DateTime date;
  final String title;
  final MonthlyMilestoneSource source;
  final String? badgeId;

  const MonthlyMilestone({
    required this.date,
    required this.title,
    required this.source,
    this.badgeId,
  });
}

/// Agregados para o relatório mensal.
class MonthlyReportSnapshot {
  final int year;
  final int month;

  final List<MonthlyGrowthPoint> weightPoints;
  final List<MonthlyGrowthPoint> heightPoints;

  /// Média aritmética dos registos de peso no mês (kg).
  final double? avgWeightKg;

  /// Ganho primeiro→último registo no mês (gramas); null se menos de 2 registos.
  final int? weightGainGrams;

  final double? avgHeightCm;
  final double? heightGainCm;

  /// Média diária de horas de sono no mês civil.
  final double avgSleepHoursDaily;

  /// Variação % vs média diária do mês anterior.
  final double? sleepTrendVsPrevMonthPct;

  /// Chaves: sleep_trend_up | sleep_trend_stable | sleep_trend_down | sleep_trend_unknown
  final String sleepTrendKey;

  /// Etiquetas curtas das 1–2 semanas com mais sono total (ex.: "12–18 Mai").
  final List<String> bestWeekLabels;

  /// Média de mamadas por dia (peito/mamadeira).
  final double avgFeedsPerDay;

  /// Horas do dia (0–23) mais frequentes para o fim da mamada.
  final List<int> topFeedingHours;

  final List<MonthlyMilestone> milestones;

  /// Memórias com foto para galeria.
  final List<BabyMemory> memoriesWithPhoto;

  const MonthlyReportSnapshot({
    required this.year,
    required this.month,
    required this.weightPoints,
    required this.heightPoints,
    required this.avgWeightKg,
    required this.weightGainGrams,
    required this.avgHeightCm,
    required this.heightGainCm,
    required this.avgSleepHoursDaily,
    required this.sleepTrendVsPrevMonthPct,
    required this.sleepTrendKey,
    required this.bestWeekLabels,
    required this.avgFeedsPerDay,
    required this.topFeedingHours,
    required this.milestones,
    required this.memoriesWithPhoto,
  });
}
