class BabyMemory {
  final int? id;
  final int babyId;
  final String badgeId;
  final String title;
  final String? description;
  final String? photoB64;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime memoryDate;
  final String? babyAgeAtMoment; // stored snapshot text, e.g. "10 dias"
  final double? weightAtMoment;
  final double? heightAtMoment;
  final String? moodAtMoment;
  final String? motherNotes;
  final bool isFavorite;

  const BabyMemory({
    this.id,
    required this.babyId,
    required this.badgeId,
    required this.title,
    required this.createdAt,
    required this.memoryDate,
    this.description,
    this.photoB64,
    this.photoUrl,
    this.babyAgeAtMoment,
    this.weightAtMoment,
    this.heightAtMoment,
    this.moodAtMoment,
    this.motherNotes,
    this.isFavorite = false,
  });

  BabyMemory copyWith({
    int? id,
    int? babyId,
    String? badgeId,
    String? title,
    DateTime? createdAt,
    DateTime? memoryDate,
    String? description,
    String? photoB64,
    String? photoUrl,
    String? babyAgeAtMoment,
    double? weightAtMoment,
    double? heightAtMoment,
    String? moodAtMoment,
    String? motherNotes,
    bool? isFavorite,
  }) {
    return BabyMemory(
      id: id ?? this.id,
      babyId: babyId ?? this.babyId,
      badgeId: badgeId ?? this.badgeId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      memoryDate: memoryDate ?? this.memoryDate,
      description: description ?? this.description,
      photoB64: photoB64 ?? this.photoB64,
      photoUrl: photoUrl ?? this.photoUrl,
      babyAgeAtMoment: babyAgeAtMoment ?? this.babyAgeAtMoment,
      weightAtMoment: weightAtMoment ?? this.weightAtMoment,
      heightAtMoment: heightAtMoment ?? this.heightAtMoment,
      moodAtMoment: moodAtMoment ?? this.moodAtMoment,
      motherNotes: motherNotes ?? this.motherNotes,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  static BabyMemory fromRow(Map<String, Object?> r) {
    DateTime parseDt(Object? v) => DateTime.tryParse((v as String?) ?? '') ?? DateTime.now();
    double? parseD(Object? v) => (v is num) ? v.toDouble() : (v == null ? null : double.tryParse(v.toString()));
    final fav = (r['is_favorite'] as int?) ?? 0;
    return BabyMemory(
      id: (r['id'] as num?)?.toInt(),
      babyId: (r['baby_id'] as num).toInt(),
      badgeId: (r['badge_id'] as String?) ?? '',
      title: (r['title'] as String?) ?? '—',
      description: (r['description'] as String?)?.trim().isEmpty == true ? null : (r['description'] as String?),
      photoB64: (r['photo_b64'] as String?)?.trim().isEmpty == true ? null : (r['photo_b64'] as String?),
      photoUrl: (r['photo_path'] as String?)?.trim().isEmpty == true ? null : (r['photo_path'] as String?),
      createdAt: parseDt(r['created_at']),
      memoryDate: parseDt(r['memory_date']),
      babyAgeAtMoment: (r['baby_age_at_moment'] as String?)?.trim().isEmpty == true ? null : (r['baby_age_at_moment'] as String?),
      weightAtMoment: parseD(r['weight_at_moment']),
      heightAtMoment: parseD(r['height_at_moment']),
      moodAtMoment: (r['mood_at_moment'] as String?)?.trim().isEmpty == true ? null : (r['mood_at_moment'] as String?),
      motherNotes: (r['mother_notes'] as String?)?.trim().isEmpty == true ? null : (r['mother_notes'] as String?),
      isFavorite: fav == 1,
    );
  }
}

