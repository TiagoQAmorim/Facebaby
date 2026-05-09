class BabyDailyTip {
  final String id;
  final String phaseKey;
  final int minAgeMonths;
  final int maxAgeMonths;
  /// Texto principal (PT-BR) em `baby_daily_tips_500.json`.
  final String text;
  /// Tradução opcional (ex.: inglês em `text_en`).
  final String? textEn;

  const BabyDailyTip({
    required this.id,
    required this.phaseKey,
    required this.minAgeMonths,
    required this.maxAgeMonths,
    required this.text,
    this.textEn,
  });

  factory BabyDailyTip.fromJson(Map<String, dynamic> json) {
    final en = json['text_en'] as String?;
    return BabyDailyTip(
      id: json['id'] as String? ?? '',
      phaseKey: json['phaseKey'] as String? ?? '',
      minAgeMonths: (json['minAgeMonths'] as num?)?.round() ?? 0,
      maxAgeMonths: (json['maxAgeMonths'] as num?)?.round() ?? 0,
      text: json['text'] as String? ?? '',
      textEn: (en != null && en.trim().isNotEmpty) ? en.trim() : null,
    );
  }
}
