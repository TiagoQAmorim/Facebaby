import '../data/growth_curves.dart';
import '../models/growth_measurement_point.dart';

/// How the child's measurement compares to the reference band (informative only).
enum GrowthReferenceBand {
  withinHealthy,
  aboveHealthyMax,
  belowHealthyMin,
  unknown,
}

/// Velocity trend vs expected daily growth for age.
enum GrowthVelocityTrend {
  healthy,
  slightSlowdownStillHealthy,
  acceleration,
  stable,
  belowExpectedStillGentle,
  notEnoughData,
}

class GrowthAnalysisResult {
  const GrowthAnalysisResult({
    required this.referenceBand,
    required this.velocityTrend,
    this.latestValue,
    this.latestAgeDays,
    this.velocityPerDay,
    this.expectedVelocityMin,
    this.expectedVelocityMax,
    this.valueDelta,
    this.measurementSpanDays,
    this.referenceAtAge,
  });

  final GrowthReferenceBand referenceBand;
  final GrowthVelocityTrend velocityTrend;
  final double? latestValue;
  final int? latestAgeDays;
  final double? velocityPerDay;
  final double? expectedVelocityMin;
  final double? expectedVelocityMax;
  final double? valueDelta;
  final int? measurementSpanDays;
  final GrowthCurvePoint? referenceAtAge;
}

/// Compares measurements to sex-specific healthy reference bands (non-diagnostic).
class GrowthAnalyzerService {
  const GrowthAnalyzerService();

  GrowthAnalysisResult analyzeHeight({
    required GrowthCurveSex sex,
    required List<GrowthMeasurementPoint> measurements,
  }) {
    final filtered = measurements.where((m) => m.heightCm != null).toList();
    return _analyze(
      sex: sex,
      measurements: filtered,
      readValue: (m) => m.heightCm!,
      band: (v, ref) => _band(
        v,
        ref.minHeightCm,
        ref.maxHeightCm,
      ),
      expectedMin: (ref) => ref.expectedGrowthPerDayMin,
      expectedMax: (ref) => ref.expectedGrowthPerDayMax,
      stableThreshold: 0.05,
    );
  }

  GrowthAnalysisResult analyzeWeight({
    required GrowthCurveSex sex,
    required List<GrowthMeasurementPoint> measurements,
  }) {
    final filtered = measurements.where((m) => m.weightKg != null).toList();
    return _analyze(
      sex: sex,
      measurements: filtered,
      readValue: (m) => m.weightKg!,
      band: (v, ref) => _band(
        v,
        ref.minWeightKg,
        ref.maxWeightKg,
      ),
      expectedMin: (ref) => ref.expectedWeightGainPerDayMin,
      expectedMax: (ref) => ref.expectedWeightGainPerDayMax,
      stableThreshold: 0.02,
    );
  }

  GrowthAnalysisResult _analyze({
    required GrowthCurveSex sex,
    required List<GrowthMeasurementPoint> measurements,
    required double Function(GrowthMeasurementPoint) readValue,
    required GrowthReferenceBand Function(double, GrowthCurvePoint) band,
    required double Function(GrowthCurvePoint) expectedMin,
    required double Function(GrowthCurvePoint) expectedMax,
    required double stableThreshold,
  }) {
    if (measurements.isEmpty) {
      return const GrowthAnalysisResult(
        referenceBand: GrowthReferenceBand.unknown,
        velocityTrend: GrowthVelocityTrend.notEnoughData,
      );
    }

    final sorted = List<GrowthMeasurementPoint>.from(measurements)
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    final curve = GrowthCurves.curveFor(sex);
    final latest = sorted.last;
    final ref = GrowthCurves.interpolate(curve, latest.ageDays);
    final latestValue = readValue(latest);
    final referenceBand = band(latestValue, ref);

    double? velocity;
    double? delta;
    int? spanDays;
    var velocityTrend = GrowthVelocityTrend.notEnoughData;

    if (sorted.length >= 2) {
      final prev = sorted[sorted.length - 2];
      spanDays = (latest.measuredAt.difference(prev.measuredAt).inDays).clamp(1, 9999);
      delta = latestValue - readValue(prev);
      velocity = delta / spanDays;
      velocityTrend = _velocityTrend(
        velocity: velocity,
        ref: ref,
        delta: delta,
        spanDays: spanDays,
        expectedMin: expectedMin(ref),
        expectedMax: expectedMax(ref),
        stableThreshold: stableThreshold,
      );
    } else if (sorted.length == 1) {
      velocityTrend = GrowthVelocityTrend.stable;
    }

    return GrowthAnalysisResult(
      referenceBand: referenceBand,
      velocityTrend: velocityTrend,
      latestValue: latestValue,
      latestAgeDays: latest.ageDays,
      velocityPerDay: velocity,
      expectedVelocityMin: expectedMin(ref),
      expectedVelocityMax: expectedMax(ref),
      valueDelta: delta,
      measurementSpanDays: spanDays,
      referenceAtAge: ref,
    );
  }

  GrowthReferenceBand _band(double value, double min, double max) {
    if (value < min) return GrowthReferenceBand.belowHealthyMin;
    if (value > max) return GrowthReferenceBand.aboveHealthyMax;
    return GrowthReferenceBand.withinHealthy;
  }

  GrowthVelocityTrend _velocityTrend({
    required double velocity,
    required GrowthCurvePoint ref,
    required double delta,
    required int spanDays,
    required double expectedMin,
    required double expectedMax,
    required double stableThreshold,
  }) {
    if (velocity >= expectedMin * 0.85 && velocity <= expectedMax * 1.15) {
      if (delta.abs() < stableThreshold && spanDays > 14) {
        return GrowthVelocityTrend.stable;
      }
      return GrowthVelocityTrend.healthy;
    }
    if (velocity > expectedMax * 1.15) {
      return GrowthVelocityTrend.acceleration;
    }
    if (velocity >= expectedMin * 0.55) {
      return GrowthVelocityTrend.slightSlowdownStillHealthy;
    }
    return GrowthVelocityTrend.belowExpectedStillGentle;
  }
}
