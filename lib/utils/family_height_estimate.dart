/// Estimativa de altura-alvo familiar (referência pediátrica simplificada).
class FamilyHeightEstimate {
  final double motherCm;
  final double fatherCm;
  final bool isGirl;

  const FamilyHeightEstimate({
    required this.motherCm,
    required this.fatherCm,
    required this.isGirl,
  });

  double get resultCm {
    if (isGirl) {
      return (fatherCm + motherCm - 13) / 2;
    }
    return (fatherCm + motherCm + 13) / 2;
  }

  static double? tryCompute({
    required String? babySex,
    required double? motherHeightCm,
    required double? fatherHeightCm,
  }) {
    if (babySex != 'M' && babySex != 'F') return null;
    if (motherHeightCm == null || motherHeightCm <= 0) return null;
    if (fatherHeightCm == null || fatherHeightCm <= 0) return null;
    final est = FamilyHeightEstimate(
      motherCm: motherHeightCm,
      fatherCm: fatherHeightCm,
      isGirl: babySex == 'F',
    );
    return est.resultCm;
  }
}

int ageInYears(DateTime birth, DateTime now) {
  var years = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) {
    years--;
  }
  return years < 0 ? 0 : years;
}
