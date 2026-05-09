class Baby {
  final String name;
  final String ageLabel;
  final String avatar;
  final double weightKg;
  final double heightCm;
  final String sex; // 'F' or 'M'
  final String? photoB64;
  /// CDN URL quando a foto já foi enviada (reinstalar / sync).
  final String? photoUrl;
  /// Calendar birth date when known (used for age-based Home shortcuts).
  final DateTime? birthDate;

  const Baby({
    required this.name,
    required this.ageLabel,
    required this.avatar,
    required this.weightKg,
    required this.heightCm,
    this.sex = 'F',
    this.photoB64,
    this.photoUrl,
    this.birthDate,
  });
}
