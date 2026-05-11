import 'public_visibility_status.dart';

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

  /// Opt-in explícito para participação na Foto da Semana (default **false**).
  final bool isPublic;
  final DateTime? publicEnabledAt;
  final DateTime? publicDisabledAt;

  /// Derivado ao gravar: Mon–Qui da semana do sorteio e com foto.
  final bool eligibleForWeeklyPhoto;

  /// Preenchido quando a nuvem marca esta memória como vencedora.
  final bool weeklyPhotoWinner;
  final String? weeklyPhotoWeekId;

  /// `showBabyFirstNameWhenPublic`: só primeiro nome no mural público quando true.
  final bool showBabyFirstNameWhenPublic;

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
    this.isPublic = false,
    this.publicEnabledAt,
    this.publicDisabledAt,
    this.eligibleForWeeklyPhoto = false,
    this.weeklyPhotoWinner = false,
    this.weeklyPhotoWeekId,
    this.showBabyFirstNameWhenPublic = true,
  });

  PublicVisibilityStatus get publicVisibilityStatus {
    if (weeklyPhotoWinner) return PublicVisibilityStatus.selected;
    if (isPublic) return PublicVisibilityStatus.public;
    if (publicDisabledAt != null && !isPublic) return PublicVisibilityStatus.expired;
    return PublicVisibilityStatus.private;
  }

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
    bool? isPublic,
    DateTime? publicEnabledAt,
    DateTime? publicDisabledAt,
    bool? eligibleForWeeklyPhoto,
    bool? weeklyPhotoWinner,
    String? weeklyPhotoWeekId,
    bool? showBabyFirstNameWhenPublic,
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
      isPublic: isPublic ?? this.isPublic,
      publicEnabledAt: publicEnabledAt ?? this.publicEnabledAt,
      publicDisabledAt: publicDisabledAt ?? this.publicDisabledAt,
      eligibleForWeeklyPhoto: eligibleForWeeklyPhoto ?? this.eligibleForWeeklyPhoto,
      weeklyPhotoWinner: weeklyPhotoWinner ?? this.weeklyPhotoWinner,
      weeklyPhotoWeekId: weeklyPhotoWeekId ?? this.weeklyPhotoWeekId,
      showBabyFirstNameWhenPublic: showBabyFirstNameWhenPublic ?? this.showBabyFirstNameWhenPublic,
    );
  }

  static BabyMemory fromRow(Map<String, Object?> r) {
    DateTime parseDt(Object? v) => DateTime.tryParse((v as String?) ?? '') ?? DateTime.now();
    DateTime? parseDtOrNull(Object? v) {
      final s = (v as String?)?.trim();
      if (s == null || s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    double? parseD(Object? v) => (v is num) ? v.toDouble() : (v == null ? null : double.tryParse(v.toString()));
    final fav = (r['is_favorite'] as int?) ?? 0;
    final pub = (r['is_public'] as int?) ?? 0;
    final elig = (r['eligible_weekly_photo'] as int?) ?? 0;
    final win = (r['weekly_photo_winner'] as int?) ?? 0;
    final showName = (r['show_baby_name_public'] as int?) ?? 1;

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
      isPublic: pub == 1,
      publicEnabledAt: parseDtOrNull(r['public_enabled_at']),
      publicDisabledAt: parseDtOrNull(r['public_disabled_at']),
      eligibleForWeeklyPhoto: elig == 1,
      weeklyPhotoWinner: win == 1,
      weeklyPhotoWeekId: (r['weekly_photo_week_id'] as String?)?.trim().isEmpty == true ? null : r['weekly_photo_week_id'] as String?,
      showBabyFirstNameWhenPublic: showName == 1,
    );
  }
}
