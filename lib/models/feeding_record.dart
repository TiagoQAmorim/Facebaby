class FeedingRecord {
  final int id;
  final int babyId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSec;
  final String? side;
  final String? type;
  final double? quantityMl;
  final String? note;

  const FeedingRecord({
    required this.id,
    required this.babyId,
    required this.startedAt,
    required this.endedAt,
    required this.durationSec,
    required this.side,
    required this.type,
    required this.quantityMl,
    required this.note,
  });

  factory FeedingRecord.fromRow(Map<String, Object?> row) {
    DateTime parse(String v) {
      final d = DateTime.parse(v);
      return d.isUtc ? d.toLocal() : d;
    }

    return FeedingRecord(
      id: ((row['id'] as num?) ?? 0).toInt(),
      babyId: (row['baby_id'] as num).toInt(),
      startedAt: parse((row['started_at'] as String?) ?? DateTime.now().toIso8601String()),
      endedAt: parse((row['ended_at'] as String?) ?? DateTime.now().toIso8601String()),
      durationSec: ((row['duration_sec'] as num?) ?? 0).toInt(),
      side: row['side'] as String?,
      type: row['type'] as String?,
      quantityMl: (row['quantity_ml'] as num?)?.toDouble(),
      note: row['note'] as String?,
    );
  }
}

