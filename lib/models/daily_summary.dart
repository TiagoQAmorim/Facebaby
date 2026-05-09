class DailySummary {
  final int feedings;
  /// Soma dos minutos (peito/mamadeira) no dia: `SUM(duration_sec) / 60` arredondado.
  final int feedingMinutesTotal;
  final String sleep;
  /// Quantidade de registos de sono terminados nesse dia (calendário local).
  final int sleepSessions;
  final int diapers;
  /// Trocas com xixi (inclui `both`).
  final int diaperPee;
  /// Trocas com cocô (inclui `both`).
  final int diaperPoo;
  final String weight;
  /// Soma dos segundos de sono nesse dia (apenas quando calculado na BD).
  final int sleepTotalSeconds;

  const DailySummary({
    required this.feedings,
    this.feedingMinutesTotal = 0,
    required this.sleep,
    this.sleepSessions = 0,
    required this.diapers,
    this.diaperPee = 0,
    this.diaperPoo = 0,
    required this.weight,
    this.sleepTotalSeconds = 0,
  });
}
