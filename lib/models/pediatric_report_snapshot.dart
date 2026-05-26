import 'pediatric_symptom_occurrence.dart';

/// Resumo clínico agregado para o relatório pediátrico (intervalo de dias civis).
class PediatricReportSnapshot {
  const PediatricReportSnapshot({
    required this.periodStart,
    required this.periodEndInclusive,
    required this.avgFeedingsPerDay,
    required this.avgSleepHoursPerDay,
    required this.avgDiapersPerDay,
    required this.weightStartKg,
    required this.weightEndKg,
    required this.weightDeltaGrams,
    required this.heightStartCm,
    required this.heightEndCm,
    required this.heightDeltaCm,
    required this.heightCm,
    required this.sleepAwakeningsAvg,
    required this.longestSleepSec,
    required this.sleepPatternKey,
    required this.hasSleepPatternBasis,
    required this.breastfeedingSessions,
    required this.formulaSessions,
    required this.solidFoodSessions,
    required this.avgBreastMinutes,
    required this.avgFormulaMinutes,
    required this.avgSolidMinutes,
    required this.vaccinesInPeriodLines,
    required this.customMedicationHints,
    required this.symptomOccurrencesByKind,
    this.growthInsightLines = const [],
  });

  /// Primeiro dia do período (data civil, início do dia).
  final DateTime periodStart;

  /// Último dia do período (data civil, inclusivo).
  final DateTime periodEndInclusive;

  final double avgFeedingsPerDay;
  final double avgSleepHoursPerDay;
  final double avgDiapersPerDay;

  final double? weightStartKg;
  final double? weightEndKg;

  /// Diferença entre primeiro e último peso no período (gramas); com fallback de peso fora do intervalo.
  final int? weightDeltaGrams;

  final double? heightStartCm;
  final double? heightEndCm;

  /// Diferença entre primeira e última altura no período (cm); com fallback de altura fora do intervalo.
  final double? heightDeltaCm;

  /// Altura: última medição no período, ou última conhecida até ao fim do período se não houver no intervalo.
  final double? heightCm;

  final double sleepAwakeningsAvg;
  final int longestSleepSec;

  /// `stable` | `moderate` | `fragmented` — só mostrar se [hasSleepPatternBasis] for verdadeiro.
  final String sleepPatternKey;

  /// Há registos de sono no intervalo analisado (evita mostrar "padrão" sem dados).
  final bool hasSleepPatternBasis;

  final int breastfeedingSessions;
  final int formulaSessions;
  final int solidFoodSessions;

  /// Duração média por tipo (minutos por mamada/refeição).
  final double? avgBreastMinutes;
  final double? avgFormulaMinutes;
  final double? avgSolidMinutes;

  /// Linhas curtas "Nome — data" para vacinas aplicadas no período.
  final List<String> vaccinesInPeriodLines;

  /// Notas em mamações/memórias que sugerem medicamento (heurística), mais medicamentos dos relatos.
  final List<String> customMedicationHints;

  /// Chaves: `reflux`, `colic`, `crying`, `pain`, `fever`, `medication`, `other`.
  final Map<String, List<PediatricSymptomOccurrence>> symptomOccurrencesByKind;

  /// Mensagens informativas da curva de crescimento (não diagnóstico).
  final List<String> growthInsightLines;
}
