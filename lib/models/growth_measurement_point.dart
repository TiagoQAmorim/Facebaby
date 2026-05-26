/// One height/weight measurement with exact age at capture time.
class GrowthMeasurementPoint {
  const GrowthMeasurementPoint({
    required this.measuredAt,
    required this.ageDays,
    this.heightCm,
    this.weightKg,
  }) : assert(heightCm != null || weightKg != null);

  final DateTime measuredAt;
  final int ageDays;
  final double? heightCm;
  final double? weightKg;
}
