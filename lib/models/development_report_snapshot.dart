/// Marco esperado para a idade (referências pediátricas simplificadas).
class DevelopmentMilestoneItem {
  const DevelopmentMilestoneItem({
    required this.id,
    required this.typicalAgeMonths,
    required this.achieved,
  });

  /// Identificador estável (ex.: motor_head).
  final String id;

  /// Idade típica em meses (aprox.) em que o marco costuma observar-se.
  final double typicalAgeMonths;

  /// Se a idade atual do bebé atinge ou ultrapassa o esperado para este marco.
  final bool achieved;
}

/// Estado agregado para o ecrã de relatório de desenvolvimento.
class DevelopmentReportSnapshot {
  const DevelopmentReportSnapshot({
    required this.referenceDay,
    required this.ageMonths,
    required this.developmentScore,
    required this.statusKey,
    required this.insightKey,
    required this.motor,
    required this.cognitive,
    required this.social,
  });

  final DateTime referenceDay;

  /// Idade em meses (decimal) na data de referência.
  final double ageMonths;

  /// 0–100 (baseado em marcos normativos em idade).
  final int developmentScore;

  /// `on_track` | `watch` | `early`
  final String statusKey;

  /// Chave para texto i18n curto de insight.
  final String insightKey;

  final List<DevelopmentMilestoneItem> motor;
  final List<DevelopmentMilestoneItem> cognitive;
  final List<DevelopmentMilestoneItem> social;
}
