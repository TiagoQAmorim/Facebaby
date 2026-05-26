import 'dart:math' as math;

import '../data/growth_curves.dart';
import '../models/growth_measurement_point.dart';

/// Builds [GrowthMeasurementPoint] lists from DB rows and baby profile.
class GrowthMeasurementsBuilder {
  GrowthMeasurementsBuilder._();

  static List<GrowthMeasurementPoint> heightFromRows({
    required DateTime? birthDate,
    required List<Map<String, Object?>> heightRows,
    double? birthHeightCm,
  }) {
    if (birthDate == null) return [];
    final birth = DateTime(birthDate.year, birthDate.month, birthDate.day);
    final points = <GrowthMeasurementPoint>[];

    if (birthHeightCm != null && birthHeightCm > 0) {
      points.add(GrowthMeasurementPoint(
        measuredAt: birth,
        ageDays: 0,
        heightCm: birthHeightCm,
      ));
    }

    final sorted = List<Map<String, Object?>>.from(heightRows)
      ..sort((a, b) {
        final am = a['measured_at'] as String? ?? '';
        final bm = b['measured_at'] as String? ?? '';
        return am.compareTo(bm);
      });

    for (final row in sorted) {
      final raw = row['measured_at'] as String?;
      final parsed = DateTime.tryParse(raw ?? '');
      if (parsed == null) continue;
      final dt = parsed.isUtc ? parsed.toLocal() : parsed;
      final h = (row['value'] as num?)?.toDouble();
      if (h == null || h <= 0) continue;
      final ageDays = GrowthCurves.ageDaysFromBirth(birth, dt);
      final day = DateTime(dt.year, dt.month, dt.day);
      if (points.any((p) {
        final pd = DateTime(p.measuredAt.year, p.measuredAt.month, p.measuredAt.day);
        return pd == day &&
            p.heightCm != null &&
            (p.heightCm! - h).abs() < 0.01;
      })) {
        continue;
      }
      points.add(GrowthMeasurementPoint(
        measuredAt: dt,
        ageDays: ageDays,
        heightCm: h,
      ));
    }

    points.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    return normalizeAgesForChart(points);
  }

  static List<GrowthMeasurementPoint> weightFromRows({
    required DateTime? birthDate,
    required List<Map<String, Object?>> weightRows,
    double? birthWeightKg,
  }) {
    if (birthDate == null) return [];
    final birth = DateTime(birthDate.year, birthDate.month, birthDate.day);
    final points = <GrowthMeasurementPoint>[];

    if (birthWeightKg != null && birthWeightKg > 0) {
      points.add(GrowthMeasurementPoint(
        measuredAt: birth,
        ageDays: 0,
        weightKg: birthWeightKg,
      ));
    }

    final sorted = List<Map<String, Object?>>.from(weightRows)
      ..sort((a, b) {
        final am = a['measured_at'] as String? ?? '';
        final bm = b['measured_at'] as String? ?? '';
        return am.compareTo(bm);
      });

    for (final row in sorted) {
      final raw = row['measured_at'] as String?;
      final parsed = DateTime.tryParse(raw ?? '');
      if (parsed == null) continue;
      final dt = parsed.isUtc ? parsed.toLocal() : parsed;
      final w = (row['value'] as num?)?.toDouble();
      if (w == null || w <= 0) continue;
      final ageDays = GrowthCurves.ageDaysFromBirth(birth, dt);
      final day = DateTime(dt.year, dt.month, dt.day);
      if (points.any((p) {
        final pd = DateTime(p.measuredAt.year, p.measuredAt.month, p.measuredAt.day);
        return pd == day &&
            p.weightKg != null &&
            (p.weightKg! - w).abs() < 0.001;
      })) {
        continue;
      }
      points.add(GrowthMeasurementPoint(
        measuredAt: dt,
        ageDays: ageDays,
        weightKg: w,
      ));
    }

    points.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    return normalizeAgesForChart(points);
  }

  /// Alinha idades para gráfico e insights (nascimento vs medições antigas).
  static List<GrowthMeasurementPoint> normalizeAgesForChart(
    List<GrowthMeasurementPoint> raw,
  ) {
    if (raw.isEmpty) return raw;
    var points = List<GrowthMeasurementPoint>.from(raw)
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    final minAge = points.map((p) => p.ageDays).reduce(math.min);
    if (minAge < 0) {
      final shift = -minAge;
      points = points
          .map(
            (p) => GrowthMeasurementPoint(
              measuredAt: p.measuredAt,
              ageDays: p.ageDays + shift,
              heightCm: p.heightCm,
              weightKg: p.weightKg,
            ),
          )
          .toList();
    }

    final distinctAges = points.map((p) => p.ageDays).toSet();
    if (points.length > 1 && distinctAges.length == 1 && distinctAges.first == 0) {
      final t0 = points.first.measuredAt;
      final t0d = DateTime(t0.year, t0.month, t0.day);
      points = points
          .map(
            (p) => GrowthMeasurementPoint(
              measuredAt: p.measuredAt,
              ageDays: DateTime(p.measuredAt.year, p.measuredAt.month, p.measuredAt.day)
                  .difference(t0d)
                  .inDays,
              heightCm: p.heightCm,
              weightKg: p.weightKg,
            ),
          )
          .toList();
    }

    return points;
  }
}
