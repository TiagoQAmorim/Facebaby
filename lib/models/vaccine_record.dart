class VaccineRecord {
  final int id;
  final int babyId;
  final String name;
  final String? dose;
  final DateTime? appliedAt;
  final DateTime? nextDueAt;
  final String? notes;
  final DateTime createdAt;

  const VaccineRecord({
    required this.id,
    required this.babyId,
    required this.name,
    required this.dose,
    required this.appliedAt,
    required this.nextDueAt,
    required this.notes,
    required this.createdAt,
  });

  factory VaccineRecord.fromRow(Map<String, Object?> row) {
    DateTime? parseDt(Object? v) => v is String ? DateTime.tryParse(v) : null;

    return VaccineRecord(
      id: ((row['id'] as num?) ?? 0).toInt(),
      babyId: (row['baby_id'] as num).toInt(),
      name: (row['name'] as String?) ?? '',
      dose: row['dose'] as String?,
      appliedAt: parseDt(row['applied_at']),
      nextDueAt: parseDt(row['next_due_at']),
      notes: row['notes'] as String?,
      createdAt: DateTime.parse((row['created_at'] as String?) ?? DateTime.now().toIso8601String()),
    );
  }
}

