import '../data/growth_curves.dart';
import '../i18n/app_i18n.dart';
import '../models/growth_measurement_point.dart';
import 'growth_analyzer_service.dart';

/// Weekly/monthly friendly messages for growth tracking (non-diagnostic).
class GrowthInsightsService {
  const GrowthInsightsService({GrowthAnalyzerService? analyzer})
      : _analyzer = analyzer ?? const GrowthAnalyzerService();

  final GrowthAnalyzerService _analyzer;

  List<String> buildHeightInsights({
    required S strings,
    required String babyName,
    required GrowthCurveSex sex,
    required List<GrowthMeasurementPoint> measurements,
    int lookbackDays = 30,
  }) =>
      _buildInsights(
        strings: strings,
        babyName: babyName,
        sex: sex,
        measurements: measurements,
        lookbackDays: lookbackDays,
        forWeight: false,
      );

  List<String> buildWeightInsights({
    required S strings,
    required String babyName,
    required GrowthCurveSex sex,
    required List<GrowthMeasurementPoint> measurements,
    int lookbackDays = 30,
  }) =>
      _buildInsights(
        strings: strings,
        babyName: babyName,
        sex: sex,
        measurements: measurements,
        lookbackDays: lookbackDays,
        forWeight: true,
      );

  List<String> _buildInsights({
    required S strings,
    required String babyName,
    required GrowthCurveSex sex,
    required List<GrowthMeasurementPoint> measurements,
    required int lookbackDays,
    required bool forWeight,
  }) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: lookbackDays));
    final inWindow = measurements
        .where((m) => !m.measuredAt.isBefore(cutoff))
        .toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    final analysis = forWeight
        ? _analyzer.analyzeWeight(sex: sex, measurements: measurements)
        : _analyzer.analyzeHeight(sex: sex, measurements: measurements);
    final isBoy = sex == GrowthCurveSex.male;
    final ageMonths = analysis.referenceAtAge?.ageMonths ??
        ((analysis.latestAgeDays ?? 0) / 30.44).round();

    final lines = <String>[
      forWeight
          ? strings.growthInsightWeightBandMessage(
              babyName: babyName,
              isBoy: isBoy,
              ageMonths: ageMonths,
              bandKey: _bandKey(analysis.referenceBand),
            )
          : strings.growthInsightBandMessage(
              babyName: babyName,
              isBoy: isBoy,
              ageMonths: ageMonths,
              bandKey: _bandKey(analysis.referenceBand),
            ),
    ];

    if (inWindow.length >= 2) {
      final first = inWindow.first;
      final last = inWindow.last;
      final days = last.measuredAt.difference(first.measuredAt).inDays;
      if (days > 0) {
        if (forWeight) {
          final w0 = first.weightKg;
          final w1 = last.weightKg;
          if (w0 != null && w1 != null) {
            final deltaG = (w1 - w0) * 1000;
            if (deltaG.abs() >= 10) {
              lines.add(strings.growthInsightPeriodWeight(
                babyName: babyName,
                days: days,
                deltaGrams: deltaG,
              ));
            }
          }
        } else {
          final h0 = first.heightCm;
          final h1 = last.heightCm;
          if (h0 != null && h1 != null) {
            final delta = h1 - h0;
            if (delta.abs() >= 0.1) {
              lines.add(strings.growthInsightPeriodHeight(
                babyName: babyName,
                days: days,
                deltaCm: delta,
              ));
            }
          }
        }
      }
    }

    lines.add(strings.growthInsightVelocityMessage(
      trendKey: _velocityKey(analysis.velocityTrend),
    ));

    if (measurements.length >= 3) {
      lines.add(strings.growthInsightCurveConsistent);
    }

    return lines;
  }

  String disclaimer(S strings) => strings.growthCurveDisclaimer;

  static String _bandKey(GrowthReferenceBand band) => switch (band) {
        GrowthReferenceBand.withinHealthy => 'within',
        GrowthReferenceBand.aboveHealthyMax => 'above',
        GrowthReferenceBand.belowHealthyMin => 'below',
        GrowthReferenceBand.unknown => 'unknown',
      };

  static String _velocityKey(GrowthVelocityTrend t) => switch (t) {
        GrowthVelocityTrend.healthy => 'healthy',
        GrowthVelocityTrend.slightSlowdownStillHealthy => 'slowdown',
        GrowthVelocityTrend.acceleration => 'acceleration',
        GrowthVelocityTrend.stable => 'stable',
        GrowthVelocityTrend.belowExpectedStillGentle => 'gentle',
        GrowthVelocityTrend.notEnoughData => 'unknown',
      };
}
