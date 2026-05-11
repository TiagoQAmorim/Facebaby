import 'symptom_report.dart';

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
    required this.heightCm,
    required this.sleepAwakeningsAvg,
    required this.longestSleepSec,
    required this.sleepPatternKey,
    required this.breastfeedingSessions,
    required this.formulaSessions,
    required this.solidFoodSessions,
    required this.avgBreastMinutes,
    required this.avgFormulaMinutes,
    required this.avgSolidMinutes,
    required this.feverEpisodesLogged,
    required this.refluxMentionedInJournals,
    required this.colicMentionedInJournals,
    required this.irritabilityKey,
    required this.vaccinesInPeriodLines,
    required this.customMedicationHints,
    required this.symptomReportsInPeriod,
    required this.cryingNotedInSymptomReports,
    required this.painNotedInSymptomReports,
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

  /// Diferença entre primeiro e último peso na semana (gramas).
  final int? weightDeltaGrams;

  /// Última altura medida no período (ou mais recente até ao fim da semana).
  final double? heightCm;

  final double sleepAwakeningsAvg;
  final int longestSleepSec;

  /// `stable` | `moderate` | `fragmented`
  final String sleepPatternKey;

  final int breastfeedingSessions;
  final int formulaSessions;
  final int solidFoodSessions;

  /// Duração média por tipo (minutos por mamada/refeição).
  final double? avgBreastMinutes;
  final double? avgFormulaMinutes;
  final double? avgSolidMinutes;

  /// Episódios com “febre” marcada nos relatos estruturados no período.
  final int feverEpisodesLogged;

  final bool refluxMentionedInJournals;
  final bool colicMentionedInJournals;

  /// `high` | `medium` | `low` | `unknown`
  final String irritabilityKey;

  /// Linhas curtas “Nome — data” para vacinas aplicadas no período.
  final List<String> vaccinesInPeriodLines;

  /// Notas em mamações/memórias que sugerem medicamento (heurística), mais medicamentos dos relatos.
  final List<String> customMedicationHints;

  /// Relatos de sintomas com data/hora no período.
  final List<SymptomReport> symptomReportsInPeriod;

  final bool cryingNotedInSymptomReports;
  final bool painNotedInSymptomReports;
}
