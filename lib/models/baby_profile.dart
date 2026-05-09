class BabyProfile {
  final int id;
  final int motherId;
  final String name;
  final DateTime? birthDate;
  final String? zodiacSign;
  final double? weightKg;
  final double? heightCm;
  final DateTime createdAt;

  const BabyProfile({
    required this.id,
    required this.motherId,
    required this.name,
    required this.birthDate,
    required this.zodiacSign,
    required this.weightKg,
    required this.heightCm,
    required this.createdAt,
  });

  factory BabyProfile.fromRow(Map<String, Object?> row) {
    final birth = row['baby_birth_date'] as String?;
    final created = row['baby_created_at'] as String?;
    return BabyProfile(
      id: ((row['baby_id'] as num?) ?? 0).toInt(),
      motherId: (row['mother_id'] as num).toInt(),
      name: (row['baby_name'] as String?) ?? '',
      birthDate: birth == null ? null : DateTime.tryParse(birth),
      zodiacSign: row['baby_zodiac_sign'] as String?,
      weightKg: (row['baby_weight_kg'] as num?)?.toDouble(),
      heightCm: (row['baby_height_cm'] as num?)?.toDouble(),
      createdAt: DateTime.parse(created ?? DateTime.now().toIso8601String()),
    );
  }
}

