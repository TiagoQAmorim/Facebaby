import 'package:flutter/foundation.dart';

import '../controllers/current_baby_controller.dart';
import '../services/app_database.dart';

/// Peso/altura atuais para deltas de crescimento (última medição, não peso ao nascer).
class GrowthBaseline {
  GrowthBaseline._();

  /// Peso ao nascer gravado no perfil — imutável ao adicionar medições na tela Crescimento.
  static double? birthWeightKgStored(Map<String, Object?>? baby) {
    final birth = (baby?['birth_weight_kg'] as num?)?.toDouble();
    if (birth != null && birth > 0) return birth;
    return null;
  }

  /// Altura ao nascer gravada no perfil — imutável ao adicionar medições na tela Crescimento.
  static double? birthHeightCmStored(Map<String, Object?>? baby) {
    final birth = (baby?['birth_height_cm'] as num?)?.toDouble();
    if (birth != null && birth > 0) return birth;
    return null;
  }

  /// Peso ao nascer para ecrãs legados (ex.: home) — fallback ao cadastro se baseline ausente.
  static double? birthWeightKg(Map<String, Object?>? baby) {
    final stored = birthWeightKgStored(baby);
    if (stored != null) return stored;
    return (baby?['weight_kg'] as num?)?.toDouble();
  }

  /// Altura ao nascer para ecrãs legados — fallback ao cadastro se baseline ausente.
  static double? birthHeightCm(Map<String, Object?>? baby) {
    final stored = birthHeightCmStored(baby);
    if (stored != null) return stored;
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

  /// Linha da medição mais recente (por [measured_at]).
  @visibleForTesting
  static Map<String, Object?>? latestRowByMeasuredAt(
    List<Map<String, Object?>> rows,
  ) {
    Map<String, Object?>? bestRow;
    DateTime? bestAt;
    for (final row in rows) {
      final raw = row['measured_at'] as String?;
      final parsed = DateTime.tryParse(raw ?? '');
      if (parsed == null) continue;
      final at = parsed.isUtc ? parsed.toLocal() : parsed;
      final v = (row['value'] as num?)?.toDouble();
      if (v == null || v <= 0) continue;
      if (bestAt == null || at.isAfter(bestAt)) {
        bestAt = at;
        bestRow = row;
      }
    }
    return bestRow;
  }

  /// Valor da medição mais recente (por [measured_at]).
  @visibleForTesting
  static double? maxValueByMeasuredAtForTest(List<Map<String, Object?>> rows) {
    final row = latestRowByMeasuredAt(rows);
    return (row?['value'] as num?)?.toDouble();
  }

  static double? _profileWeightKg() =>
      (CurrentBabyController.instance.currentBabyRow?['weight_kg'] as num?)
          ?.toDouble();

  static double? _profileHeightCm() =>
      (CurrentBabyController.instance.currentBabyRow?['height_cm'] as num?)
          ?.toDouble();

  /// Atualiza peso/altura **atuais** no cadastro após medição (Home + nuvem).
  /// Nunca altera [birth_weight_kg] / [birth_height_cm].
  static Future<void> syncBabyProfileAfterMeasurement({
    required int babyId,
    double? weightKg,
    double? heightCm,
  }) async {
    if (weightKg == null && heightCm == null) return;
    await AppDatabase.instance.patchBabyCurrentMeasurements(
      babyId: babyId,
      weightKg: weightKg,
      heightCm: heightCm,
    );
    await CurrentBabyController.instance.refresh();
  }
}
