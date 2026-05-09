class Mother {
  final int id;
  final String name;
  final String? phone;
  final DateTime? birthDate;
  final double? heightCm;
  final double? fatherHeightCm;
  final DateTime createdAt;

  const Mother({
    required this.id,
    required this.name,
    required this.phone,
    required this.birthDate,
    required this.heightCm,
    required this.fatherHeightCm,
    required this.createdAt,
  });

  factory Mother.fromRow(Map<String, Object?> row) {
    final birth = row['mother_birth_date'] as String?;
    return Mother(
      id: (row['mother_id'] as num).toInt(),
      name: (row['mother_name'] as String?) ?? '',
      phone: row['mother_phone'] as String?,
      birthDate: birth == null ? null : DateTime.tryParse(birth),
      heightCm: (row['mother_height_cm'] as num?)?.toDouble(),
      fatherHeightCm: (row['mother_father_height_cm'] as num?)?.toDouble(),
      createdAt: DateTime.parse((row['mother_created_at'] as String?) ?? DateTime.now().toIso8601String()),
    );
  }
}

