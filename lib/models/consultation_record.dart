class ConsultationRecord {
  final int id;
  final int babyId;
  final String title;
  final String? notes;
  final String? phone;
  final String? address;
  final DateTime occurredAt;
  final DateTime createdAt;

  const ConsultationRecord({
    required this.id,
    required this.babyId,
    required this.title,
    required this.notes,
    required this.phone,
    required this.address,
    required this.occurredAt,
    required this.createdAt,
  });

  factory ConsultationRecord.fromRow(Map<String, Object?> row) {
    DateTime? parseDt(Object? v) => v is String ? DateTime.tryParse(v) : null;

    return ConsultationRecord(
      id: ((row['id'] as num?) ?? 0).toInt(),
      babyId: (row['baby_id'] as num).toInt(),
      title: (row['title'] as String?)?.trim() ?? '',
      notes: row['notes'] as String?,
      phone: row['phone'] as String?,
      address: row['address'] as String?,
      occurredAt: parseDt(row['occurred_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      createdAt: DateTime.parse((row['created_at'] as String?) ?? DateTime.now().toIso8601String()),
    );
  }
}
