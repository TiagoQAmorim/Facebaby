import '../app_database.dart';

/// Perfil leve do bebé para personalizar mensagens emocionais da IA.
class AiBabyEmotionalContext {
  const AiBabyEmotionalContext({
    required this.babyId,
    required this.name,
    this.sex,
    this.birthDate,
    this.ageInDays = 0,
    this.ageInMonths = 0,
    this.ageInWeeks = 0,
    this.isPremature = false,
    this.hasReflux = false,
    this.hasColic = false,
    this.hasAllergies = false,
  });

  final int babyId;
  final String name;
  final String? sex;
  final DateTime? birthDate;
  final int ageInDays;
  final int ageInMonths;
  final int ageInWeeks;
  final bool isPremature;
  final bool hasReflux;
  final bool hasColic;
  final bool hasAllergies;

  bool get isGirl =>
      sex == 'F' || sex == 'female' || sex == 'girl' || sex == 'menina';
  bool get isBoy =>
      sex == 'M' || sex == 'male' || sex == 'boy' || sex == 'menino';

  static Future<AiBabyEmotionalContext> load({
    required int babyId,
    required String babyName,
    String? babySex,
    DateTime? birthDate,
  }) async {
    final now = DateTime.now();
    final birth = birthDate ??
        DateTime.tryParse(
          (await AppDatabase.instance.getBabyById(babyId))?['birth_date']
                  as String? ??
              '',
        );

    var ageDays = 0;
    var ageMonths = 0;
    var ageWeeks = 0;
    if (birth != null) {
      ageDays = now.difference(birth).inDays.clamp(0, 99999);
      ageWeeks = (ageDays / 7).floor();
      ageMonths = _fullMonthsBetween(birth, now);
    }

    final health = await _loadHealthFlags(babyId);

    return AiBabyEmotionalContext(
      babyId: babyId,
      name: babyName.trim().isEmpty ? 'bebê' : babyName.trim(),
      sex: babySex,
      birthDate: birth,
      ageInDays: ageDays,
      ageInMonths: ageMonths,
      ageInWeeks: ageWeeks,
      isPremature: health.isPremature,
      hasReflux: health.hasReflux,
      hasColic: health.hasColic,
      hasAllergies: health.hasAllergies,
    );
  }

  static int _fullMonthsBetween(DateTime birth, DateTime now) {
    if (now.isBefore(birth)) return 0;
    var months = (now.year - birth.year) * 12 + now.month - birth.month;
    if (now.day < birth.day) months--;
    return months.clamp(0, 240);
  }

  static Future<({bool isPremature, bool hasReflux, bool hasColic, bool hasAllergies})>
      _loadHealthFlags(int babyId) async {
    var premature = false;
    var reflux = false;
    var colic = false;
    var allergies = false;

    final symptoms = await AppDatabase.instance.listSymptomReports(babyId: babyId);
    for (final row in symptoms.take(40)) {
      if ((row['reflux'] as int? ?? 0) == 1) reflux = true;
      if ((row['colic'] as int? ?? 0) == 1) colic = true;
      final notes = '${row['notes'] ?? ''}'.toLowerCase();
      if (notes.contains('alerg')) allergies = true;
      if (notes.contains('prematur')) premature = true;
    }

    final baby = await AppDatabase.instance.getBabyById(babyId);
    final notes = '${baby?['notes'] ?? ''} ${baby?['health_notes'] ?? ''}'
        .toLowerCase();
    if (notes.contains('prematur')) premature = true;
    if (notes.contains('refluxo') || notes.contains('reflux')) reflux = true;
    if (notes.contains('cólica') || notes.contains('colica')) colic = true;
    if (notes.contains('alerg')) allergies = true;

    return (
      isPremature: premature,
      hasReflux: reflux,
      hasColic: colic,
      hasAllergies: allergies,
    );
  }
}
