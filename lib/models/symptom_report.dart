/// Registo local de sintomas relatados em Saúde (para o relatório pediátrico).
class SymptomReport {
  const SymptomReport({
    required this.id,
    required this.babyId,
    this.cloudId,
    required this.occurredAt,
    this.medicationNote,
    required this.fever,
    this.tempCelsius,
    required this.unexplainedCrying,
    required this.pain,
    required this.colic,
    required this.reflux,
    this.otherNote,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int babyId;

  /// `users/{uid}/events/{id}` no Firestore, quando já sincronizado.
  final String? cloudId;
  final DateTime occurredAt;

  /// Texto livre (medicamentos tomados).
  final String? medicationNote;

  final bool fever;

  /// Temperatura em ºC (base); obrigatória se [fever] for verdadeiro no formulário.
  final double? tempCelsius;

  final bool unexplainedCrying;
  final bool pain;
  final bool colic;
  final bool reflux;
  final String? otherNote;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasAnySymptom {
    final med = medicationNote?.trim().isNotEmpty == true;
    final other = otherNote?.trim().isNotEmpty == true;
    return med ||
        (fever && tempCelsius != null) ||
        unexplainedCrying ||
        pain ||
        colic ||
        reflux ||
        other;
  }

  static SymptomReport fromMap(Map<String, Object?> m) {
    final id = (m['id'] as num?)?.toInt() ?? 0;
    final babyId = (m['baby_id'] as num?)?.toInt() ?? 0;
    final occurredAt = DateTime.tryParse(m['occurred_at'] as String? ?? '') ?? DateTime.now();
    final createdAt = DateTime.tryParse(m['created_at'] as String? ?? '') ?? occurredAt;
    final updatedAt = DateTime.tryParse(m['updated_at'] as String? ?? '') ?? createdAt;
    final cid = (m['cloud_id'] as String?)?.trim();
    return SymptomReport(
      id: id,
      babyId: babyId,
      cloudId: (cid == null || cid.isEmpty) ? null : cid,
      occurredAt: occurredAt.isUtc ? occurredAt.toLocal() : occurredAt,
      medicationNote: (m['medication_note'] as String?)?.trim().isEmpty == true
          ? null
          : (m['medication_note'] as String?)?.trim(),
      fever: ((m['fever'] as num?)?.toInt() ?? 0) != 0,
      tempCelsius: (m['temp_celsius'] as num?)?.toDouble(),
      unexplainedCrying: ((m['crying'] as num?)?.toInt() ?? 0) != 0,
      pain: ((m['pain'] as num?)?.toInt() ?? 0) != 0,
      colic: ((m['colic'] as num?)?.toInt() ?? 0) != 0,
      reflux: ((m['reflux'] as num?)?.toInt() ?? 0) != 0,
      otherNote:
          (m['other_note'] as String?)?.trim().isEmpty == true ? null : (m['other_note'] as String?)?.trim(),
      createdAt: createdAt.isUtc ? createdAt.toLocal() : createdAt,
      updatedAt: updatedAt.isUtc ? updatedAt.toLocal() : updatedAt,
    );
  }
}
