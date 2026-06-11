import 'package:flutter/foundation.dart';

import '../controllers/current_baby_controller.dart';
import '../services/app_database.dart';

/// Peso/altura atuais para deltas de crescimento (última medição, não peso ao nascer).
class GrowthBaseline {
  GrowthBaseline._();

  /// Peso ao nascer (cadastro inicial) — não muda ao registrar novas medições.
  static double? birthWeightKg(Map<String, Object?>? baby) {
    final birth = (baby?['birth_weight_kg'] as num?)?.toDouble();
    if (birth != null && birth > 0) return birth;
    return (baby?['weight_kg'] as num?)?.toDouble();
  }

  /// Altura ao nascer (cadastro inicial).
  static double? birthHeightCm(Map<String, Object?>? baby) {
    final birth = (baby?['birth_height_cm'] as num?)?.toDouble();
    if (birth != null && birth > 0) return birth;
    return (baby?['height_cm'] as num?)?.toDouble();
  }

  static const int _scanLimit = 120;

  /// Último peso (kg): medições em [growth_records], senão cadastro do bebê.
  static Future<double?> latestWeightKg(int babyId) async {
    final fromRecords = await _latestValueKgOrCm(
      babyId: babyId,
      kind: 'weight',
    );
    if (fromRecords != null && fromRecords > 0) return fromRecords;
    return _profileWeightKg();
  }

  /// Última altura (cm): medições em [growth_records], senão cadastro do bebê.
  static Future<double?> latestHeightCm(int babyId) async {
    final fromRecords = await _latestValueKgOrCm(
      babyId: babyId,
      kind: 'height',
    );
    if (fromRecords != null && fromRecords > 0) return fromRecords;
    return _profileHeightCm();
  }

  static Future<double?> latestWeightKgForCurrentBaby() async {
    final id = CurrentBabyController.instance.currentBabyId;
    if (id == null) return _profileWeightKg();
    return latestWeightKg(id);
  }

  static Future<double?> latestHeightCmForCurrentBaby() async {
    final id = CurrentBabyController.instance.currentBabyId;
    if (id == null) return _profileHeightCm();
    return latestHeightCm(id);
  }

  static Future<double?> _latestValueKgOrCm({
    required int babyId,
    required String kind,
  }) async {
    final rows = await AppDatabase.instance.listGrowthRecords(
      babyId: babyId,
      kind: kind,
      limit: _scanLimit,
    );
    return maxValueByMeasuredAtForTest(rows);
  }

  /// Escolhe o valor da medição mais recente (por [measured_at]).
  @visibleForTesting
  static double? maxValueByMeasuredAtForTest(List<Map<String, Object?>> rows) {
    DateTime? bestAt;
    double? bestVal;
    for (final row in rows) {
      final raw = row['measured_at'] as String?;
      final parsed = DateTime.tryParse(raw ?? '');
      if (parsed == null) continue;
      final at = parsed.isUtc ? parsed.toLocal() : parsed;
      final v = (row['value'] as num?)?.toDouble();
      if (v == null || v <= 0) continue;
      if (bestAt == null || at.isAfter(bestAt)) {
        bestAt = at;
        bestVal = v;
      }
    }
    return bestVal;
  }

  static double? _profileWeightKg() =>
      (CurrentBabyController.instance.currentBabyRow?['weight_kg'] as num?)
          ?.toDouble();

  static double? _profileHeightCm() =>
      (CurrentBabyController.instance.currentBabyRow?['height_cm'] as num?)
          ?.toDouble();

  /// Atualiza peso/altura **atuais** no cadastro após medição (Home + nuvem).
  /// Não altera [birth_weight_kg] / [birth_height_cm] usados nas curvas ao nascer.
  static Future<void> syncBabyProfileAfterMeasurement({
    required int babyId,
    double? weightKg,
    double? heightCm,
  }) async {
    if (weightKg == null && heightCm == null) return;
    final baby = await AppDatabase.instance.getBabyById(babyId);
    if (baby == null) return;
    final motherId = (baby['mother_id'] as num?)?.toInt();
    if (motherId == null) return;

    final name = (baby['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return;

    final birthRaw = baby['birth_date'] as String?;
    final birthDate = birthRaw != null && birthRaw.isNotEmpty
        ? DateTime.tryParse(birthRaw)
        : null;

    await AppDatabase.instance.updateBaby(
      babyId: babyId,
      motherId: motherId,
      name: name,
      sex: (baby['sex'] as String?)?.trim().isEmpty == true
          ? 'F'
          : (baby['sex'] as String?) ?? 'F',
      birthDate: birthDate,
      zodiacSign: baby['zodiac_sign'] as String?,
      weightKg: weightKg ?? (baby['weight_kg'] as num?)?.toDouble(),
      heightCm: heightCm ?? (baby['height_cm'] as num?)?.toDouble(),
      photoB64: baby['photo_b64'] as String?,
      touchBirthBaseline: false,
    );
    await CurrentBabyController.instance.refresh();
  }
}
