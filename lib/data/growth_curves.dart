// Reference growth curves (height + weight, FaceBaby / WHO-inspired tables).

/// One row of the healthy growth reference band.
class GrowthCurvePoint {
  const GrowthCurvePoint({
    required this.ageMonths,
    required this.ageDays,
    required this.minHeightCm,
    required this.avgHeightCm,
    required this.maxHeightCm,
    required this.minWeightKg,
    required this.avgWeightKg,
    required this.maxWeightKg,
    required this.expectedGrowthPerDayMin,
    required this.expectedGrowthPerDayMax,
    required this.expectedWeightGainPerDayMin,
    required this.expectedWeightGainPerDayMax,
  });

  final int ageMonths;
  final int ageDays;
  final double minHeightCm;
  final double avgHeightCm;
  final double maxHeightCm;
  final double minWeightKg;
  final double avgWeightKg;
  final double maxWeightKg;
  final double expectedGrowthPerDayMin;
  final double expectedGrowthPerDayMax;
  final double expectedWeightGainPerDayMin;
  final double expectedWeightGainPerDayMax;
}

/// Baby sex for curve lookup (`F`/`M` from profile; unknown defaults to girls).
enum GrowthCurveSex { female, male }

/// Chart metric for reference curves.
enum GrowthChartMetric { height, weight }

const List<GrowthCurvePoint> girlsGrowthCurve = [
  GrowthCurvePoint(ageMonths: 0, ageDays: 0, minHeightCm: 45.4, avgHeightCm: 49.1, maxHeightCm: 52.9, minWeightKg: 2.4, avgWeightKg: 3.2, maxWeightKg: 4.2, expectedGrowthPerDayMin: 0.090, expectedGrowthPerDayMax: 0.130, expectedWeightGainPerDayMin: 0.02667, expectedWeightGainPerDayMax: 0.04333),
  GrowthCurvePoint(ageMonths: 1, ageDays: 30, minHeightCm: 49.8, avgHeightCm: 53.7, maxHeightCm: 57.6, minWeightKg: 3.2, avgWeightKg: 4.2, maxWeightKg: 5.5, expectedGrowthPerDayMin: 0.090, expectedGrowthPerDayMax: 0.130, expectedWeightGainPerDayMin: 0.02667, expectedWeightGainPerDayMax: 0.04333),
  GrowthCurvePoint(ageMonths: 2, ageDays: 61, minHeightCm: 53.0, avgHeightCm: 57.1, maxHeightCm: 61.1, minWeightKg: 4.0, avgWeightKg: 5.1, maxWeightKg: 6.6, expectedGrowthPerDayMin: 0.090, expectedGrowthPerDayMax: 0.130, expectedWeightGainPerDayMin: 0.02581, expectedWeightGainPerDayMax: 0.03548),
  GrowthCurvePoint(ageMonths: 3, ageDays: 91, minHeightCm: 55.6, avgHeightCm: 59.8, maxHeightCm: 64.0, minWeightKg: 4.6, avgWeightKg: 5.8, maxWeightKg: 7.4, expectedGrowthPerDayMin: 0.060, expectedGrowthPerDayMax: 0.080, expectedWeightGainPerDayMin: 0.02000, expectedWeightGainPerDayMax: 0.02667),
  GrowthCurvePoint(ageMonths: 4, ageDays: 122, minHeightCm: 57.8, avgHeightCm: 62.1, maxHeightCm: 66.4, minWeightKg: 5.1, avgWeightKg: 6.4, maxWeightKg: 8.1, expectedGrowthPerDayMin: 0.060, expectedGrowthPerDayMax: 0.080, expectedWeightGainPerDayMin: 0.01613, expectedWeightGainPerDayMax: 0.02258),
  GrowthCurvePoint(ageMonths: 5, ageDays: 152, minHeightCm: 59.6, avgHeightCm: 64.0, maxHeightCm: 68.5, minWeightKg: 5.5, avgWeightKg: 6.9, maxWeightKg: 8.7, expectedGrowthPerDayMin: 0.060, expectedGrowthPerDayMax: 0.080, expectedWeightGainPerDayMin: 0.01333, expectedWeightGainPerDayMax: 0.02000),
  GrowthCurvePoint(ageMonths: 6, ageDays: 183, minHeightCm: 61.2, avgHeightCm: 65.7, maxHeightCm: 70.3, minWeightKg: 5.8, avgWeightKg: 7.3, maxWeightKg: 9.2, expectedGrowthPerDayMin: 0.030, expectedGrowthPerDayMax: 0.050, expectedWeightGainPerDayMin: 0.00968, expectedWeightGainPerDayMax: 0.01613),
  GrowthCurvePoint(ageMonths: 7, ageDays: 213, minHeightCm: 62.7, avgHeightCm: 67.3, maxHeightCm: 72.1, minWeightKg: 6.1, avgWeightKg: 7.6, maxWeightKg: 9.6, expectedGrowthPerDayMin: 0.030, expectedGrowthPerDayMax: 0.050, expectedWeightGainPerDayMin: 0.01000, expectedWeightGainPerDayMax: 0.01333),
  GrowthCurvePoint(ageMonths: 8, ageDays: 244, minHeightCm: 64.0, avgHeightCm: 68.7, maxHeightCm: 73.7, minWeightKg: 6.3, avgWeightKg: 7.9, maxWeightKg: 10.0, expectedGrowthPerDayMin: 0.030, expectedGrowthPerDayMax: 0.050, expectedWeightGainPerDayMin: 0.00645, expectedWeightGainPerDayMax: 0.01290),
  GrowthCurvePoint(ageMonths: 9, ageDays: 274, minHeightCm: 65.3, avgHeightCm: 70.1, maxHeightCm: 75.3, minWeightKg: 6.5, avgWeightKg: 8.2, maxWeightKg: 10.4, expectedGrowthPerDayMin: 0.030, expectedGrowthPerDayMax: 0.050, expectedWeightGainPerDayMin: 0.00667, expectedWeightGainPerDayMax: 0.01333),
  GrowthCurvePoint(ageMonths: 10, ageDays: 304, minHeightCm: 66.5, avgHeightCm: 71.5, maxHeightCm: 76.8, minWeightKg: 6.7, avgWeightKg: 8.5, maxWeightKg: 10.8, expectedGrowthPerDayMin: 0.030, expectedGrowthPerDayMax: 0.050, expectedWeightGainPerDayMin: 0.00667, expectedWeightGainPerDayMax: 0.01333),
  GrowthCurvePoint(ageMonths: 11, ageDays: 335, minHeightCm: 67.7, avgHeightCm: 72.8, maxHeightCm: 78.3, minWeightKg: 6.9, avgWeightKg: 8.7, maxWeightKg: 11.1, expectedGrowthPerDayMin: 0.030, expectedGrowthPerDayMax: 0.050, expectedWeightGainPerDayMin: 0.00645, expectedWeightGainPerDayMax: 0.00968),
  GrowthCurvePoint(ageMonths: 12, ageDays: 365, minHeightCm: 68.9, avgHeightCm: 74.0, maxHeightCm: 79.8, minWeightKg: 7.0, avgWeightKg: 8.9, maxWeightKg: 11.5, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.035, expectedWeightGainPerDayMin: 0.00333, expectedWeightGainPerDayMax: 0.01333),
  GrowthCurvePoint(ageMonths: 13, ageDays: 396, minHeightCm: 69.8, avgHeightCm: 75.1, maxHeightCm: 81.1, minWeightKg: 7.186338797814208, avgWeightKg: 9.120218579234972, maxWeightKg: 11.754098360655737, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.035, expectedWeightGainPerDayMin: 0.00601, expectedWeightGainPerDayMax: 0.00820),
  GrowthCurvePoint(ageMonths: 14, ageDays: 426, minHeightCm: 70.6, avgHeightCm: 76.2, maxHeightCm: 82.4, minWeightKg: 7.366666666666666, avgWeightKg: 9.333333333333334, maxWeightKg: 12.0, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.035, expectedWeightGainPerDayMin: 0.00601, expectedWeightGainPerDayMax: 0.00820),
  GrowthCurvePoint(ageMonths: 15, ageDays: 457, minHeightCm: 71.5, avgHeightCm: 77.3, maxHeightCm: 83.7, minWeightKg: 7.553005464480874, avgWeightKg: 9.553551912568306, maxWeightKg: 12.254098360655737, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.035, expectedWeightGainPerDayMin: 0.00601, expectedWeightGainPerDayMax: 0.00820),
  GrowthCurvePoint(ageMonths: 16, ageDays: 487, minHeightCm: 72.3, avgHeightCm: 78.5, maxHeightCm: 84.9, minWeightKg: 7.733333333333333, avgWeightKg: 9.766666666666666, maxWeightKg: 12.5, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.035, expectedWeightGainPerDayMin: 0.00601, expectedWeightGainPerDayMax: 0.00820),
  GrowthCurvePoint(ageMonths: 17, ageDays: 517, minHeightCm: 73.2, avgHeightCm: 79.6, maxHeightCm: 86.2, minWeightKg: 7.913661202185792, avgWeightKg: 9.979781420765027, maxWeightKg: 12.745901639344263, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.035, expectedWeightGainPerDayMin: 0.00601, expectedWeightGainPerDayMax: 0.00820),
  GrowthCurvePoint(ageMonths: 18, ageDays: 548, minHeightCm: 74.0, avgHeightCm: 80.7, maxHeightCm: 87.5, minWeightKg: 8.1, avgWeightKg: 10.2, maxWeightKg: 13.0, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.035, expectedWeightGainPerDayMin: 0.00601, expectedWeightGainPerDayMax: 0.00820),
  GrowthCurvePoint(ageMonths: 19, ageDays: 578, minHeightCm: 74.9, avgHeightCm: 81.7, maxHeightCm: 88.6, minWeightKg: 8.248351648351647, avgWeightKg: 10.414285714285715, maxWeightKg: 13.296703296703297, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.035, expectedWeightGainPerDayMin: 0.00495, expectedWeightGainPerDayMax: 0.00989),
  GrowthCurvePoint(ageMonths: 20, ageDays: 609, minHeightCm: 75.8, avgHeightCm: 82.6, maxHeightCm: 89.6, minWeightKg: 8.401648351648351, avgWeightKg: 10.635714285714286, maxWeightKg: 13.603296703296703, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.035, expectedWeightGainPerDayMin: 0.00495, expectedWeightGainPerDayMax: 0.00989),
  GrowthCurvePoint(ageMonths: 21, ageDays: 639, minHeightCm: 76.7, avgHeightCm: 83.6, maxHeightCm: 90.7, minWeightKg: 8.55, avgWeightKg: 10.85, maxWeightKg: 13.9, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.035, expectedWeightGainPerDayMin: 0.00495, expectedWeightGainPerDayMax: 0.00989),
  GrowthCurvePoint(ageMonths: 22, ageDays: 670, minHeightCm: 77.6, avgHeightCm: 84.5, maxHeightCm: 91.8, minWeightKg: 8.703296703296703, avgWeightKg: 11.071428571428571, maxWeightKg: 14.206593406593408, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.035, expectedWeightGainPerDayMin: 0.00495, expectedWeightGainPerDayMax: 0.00989),
  GrowthCurvePoint(ageMonths: 23, ageDays: 700, minHeightCm: 78.5, avgHeightCm: 85.5, maxHeightCm: 92.8, minWeightKg: 8.851648351648352, avgWeightKg: 11.285714285714285, maxWeightKg: 14.503296703296703, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.035, expectedWeightGainPerDayMin: 0.00495, expectedWeightGainPerDayMax: 0.00989),
  GrowthCurvePoint(ageMonths: 24, ageDays: 730, minHeightCm: 79.4, avgHeightCm: 86.4, maxHeightCm: 93.9, minWeightKg: 9.0, avgWeightKg: 11.5, maxWeightKg: 14.8, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00495, expectedWeightGainPerDayMax: 0.00989),
  GrowthCurvePoint(ageMonths: 25, ageDays: 761, minHeightCm: 79.9, avgHeightCm: 87.0, maxHeightCm: 94.5, minWeightKg: 9.169398907103826, avgWeightKg: 11.720218579234972, maxWeightKg: 15.087978142076503, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00546, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 26, ageDays: 791, minHeightCm: 80.4, avgHeightCm: 87.6, maxHeightCm: 95.1, minWeightKg: 9.333333333333334, avgWeightKg: 11.933333333333334, maxWeightKg: 15.366666666666667, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00546, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 27, ageDays: 822, minHeightCm: 81.0, avgHeightCm: 88.2, maxHeightCm: 95.7, minWeightKg: 9.502732240437158, avgWeightKg: 12.153551912568306, maxWeightKg: 15.65464480874317, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00546, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 28, ageDays: 852, minHeightCm: 81.5, avgHeightCm: 88.8, maxHeightCm: 96.3, minWeightKg: 9.666666666666666, avgWeightKg: 12.366666666666667, maxWeightKg: 15.933333333333334, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00546, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 29, ageDays: 883, minHeightCm: 82.0, avgHeightCm: 89.4, maxHeightCm: 96.9, minWeightKg: 9.836065573770492, avgWeightKg: 12.586885245901641, maxWeightKg: 16.221311475409838, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00546, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 30, ageDays: 913, minHeightCm: 82.5, avgHeightCm: 90.0, maxHeightCm: 97.5, minWeightKg: 10.0, avgWeightKg: 12.8, maxWeightKg: 16.5, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00546, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 31, ageDays: 944, minHeightCm: 83.2, avgHeightCm: 90.8, maxHeightCm: 98.5, minWeightKg: 10.13551912568306, avgWeightKg: 13.00327868852459, maxWeightKg: 16.77103825136612, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00874),
  GrowthCurvePoint(ageMonths: 32, ageDays: 974, minHeightCm: 84.0, avgHeightCm: 91.7, maxHeightCm: 99.4, minWeightKg: 10.266666666666667, avgWeightKg: 13.200000000000001, maxWeightKg: 17.033333333333335, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00874),
  GrowthCurvePoint(ageMonths: 33, ageDays: 1004, minHeightCm: 84.8, avgHeightCm: 92.5, maxHeightCm: 100.4, minWeightKg: 10.397814207650274, avgWeightKg: 13.39672131147541, maxWeightKg: 17.29562841530055, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00874),
  GrowthCurvePoint(ageMonths: 34, ageDays: 1035, minHeightCm: 85.5, avgHeightCm: 93.4, maxHeightCm: 101.4, minWeightKg: 10.533333333333333, avgWeightKg: 13.6, maxWeightKg: 17.566666666666666, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00874),
  GrowthCurvePoint(ageMonths: 35, ageDays: 1065, minHeightCm: 86.2, avgHeightCm: 94.2, maxHeightCm: 102.3, minWeightKg: 10.66448087431694, avgWeightKg: 13.79672131147541, maxWeightKg: 17.82896174863388, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00874),
  GrowthCurvePoint(ageMonths: 36, ageDays: 1096, minHeightCm: 87.0, avgHeightCm: 95.1, maxHeightCm: 103.3, minWeightKg: 10.8, avgWeightKg: 14.0, maxWeightKg: 18.1, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00874),
  GrowthCurvePoint(ageMonths: 37, ageDays: 1126, minHeightCm: 87.6, avgHeightCm: 95.7, maxHeightCm: 104.0, minWeightKg: 10.898630136986302, avgWeightKg: 14.172602739726027, maxWeightKg: 18.379452054794523, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00329, expectedWeightGainPerDayMax: 0.00932),
  GrowthCurvePoint(ageMonths: 38, ageDays: 1157, minHeightCm: 88.2, avgHeightCm: 96.4, maxHeightCm: 104.6, minWeightKg: 11.00054794520548, avgWeightKg: 14.35095890410959, maxWeightKg: 18.668219178082193, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00329, expectedWeightGainPerDayMax: 0.00932),
  GrowthCurvePoint(ageMonths: 39, ageDays: 1187, minHeightCm: 88.8, avgHeightCm: 97.0, maxHeightCm: 105.3, minWeightKg: 11.09917808219178, avgWeightKg: 14.523561643835617, maxWeightKg: 18.947671232876715, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00329, expectedWeightGainPerDayMax: 0.00932),
  GrowthCurvePoint(ageMonths: 40, ageDays: 1218, minHeightCm: 89.3, avgHeightCm: 97.6, maxHeightCm: 106.0, minWeightKg: 11.20109589041096, avgWeightKg: 14.701917808219179, maxWeightKg: 19.236438356164385, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00329, expectedWeightGainPerDayMax: 0.00932),
  GrowthCurvePoint(ageMonths: 41, ageDays: 1248, minHeightCm: 89.9, avgHeightCm: 98.3, maxHeightCm: 106.6, minWeightKg: 11.299726027397261, avgWeightKg: 14.874520547945206, maxWeightKg: 19.515890410958903, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00329, expectedWeightGainPerDayMax: 0.00932),
  GrowthCurvePoint(ageMonths: 42, ageDays: 1278, minHeightCm: 90.5, avgHeightCm: 98.9, maxHeightCm: 107.3, minWeightKg: 11.398356164383562, avgWeightKg: 15.047123287671234, maxWeightKg: 19.795342465753425, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00329, expectedWeightGainPerDayMax: 0.00932),
  GrowthCurvePoint(ageMonths: 43, ageDays: 1309, minHeightCm: 91.1, avgHeightCm: 99.5, maxHeightCm: 108.0, minWeightKg: 11.50027397260274, avgWeightKg: 15.225479452054795, maxWeightKg: 20.0841095890411, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00329, expectedWeightGainPerDayMax: 0.00932),
  GrowthCurvePoint(ageMonths: 44, ageDays: 1339, minHeightCm: 91.7, avgHeightCm: 100.2, maxHeightCm: 108.6, minWeightKg: 11.598904109589041, avgWeightKg: 15.398082191780823, maxWeightKg: 20.363561643835617, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00329, expectedWeightGainPerDayMax: 0.00932),
  GrowthCurvePoint(ageMonths: 45, ageDays: 1370, minHeightCm: 92.2, avgHeightCm: 100.8, maxHeightCm: 109.3, minWeightKg: 11.70082191780822, avgWeightKg: 15.576438356164385, maxWeightKg: 20.652328767123286, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00329, expectedWeightGainPerDayMax: 0.00932),
  GrowthCurvePoint(ageMonths: 46, ageDays: 1400, minHeightCm: 92.8, avgHeightCm: 101.4, maxHeightCm: 110.0, minWeightKg: 11.799452054794521, avgWeightKg: 15.749041095890412, maxWeightKg: 20.93178082191781, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00329, expectedWeightGainPerDayMax: 0.00932),
  GrowthCurvePoint(ageMonths: 47, ageDays: 1431, minHeightCm: 93.4, avgHeightCm: 102.1, maxHeightCm: 110.6, minWeightKg: 11.901369863013699, avgWeightKg: 15.927397260273974, maxWeightKg: 21.220547945205478, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00329, expectedWeightGainPerDayMax: 0.00932),
  GrowthCurvePoint(ageMonths: 48, ageDays: 1461, minHeightCm: 94.0, avgHeightCm: 102.7, maxHeightCm: 111.3, minWeightKg: 12.0, avgWeightKg: 16.1, maxWeightKg: 21.5, expectedGrowthPerDayMin: 0.015, expectedGrowthPerDayMax: 0.025, expectedWeightGainPerDayMin: 0.00329, expectedWeightGainPerDayMax: 0.00932),
];

const List<GrowthCurvePoint> boysGrowthCurve = [
  GrowthCurvePoint(ageMonths: 0, ageDays: 0, minHeightCm: 46.1, avgHeightCm: 49.9, maxHeightCm: 53.7, minWeightKg: 2.5, avgWeightKg: 3.3, maxWeightKg: 4.3, expectedGrowthPerDayMin: 0.100, expectedGrowthPerDayMax: 0.140, expectedWeightGainPerDayMin: 0.03000, expectedWeightGainPerDayMax: 0.05000),
  GrowthCurvePoint(ageMonths: 1, ageDays: 30, minHeightCm: 50.8, avgHeightCm: 54.7, maxHeightCm: 58.6, minWeightKg: 3.4, avgWeightKg: 4.5, maxWeightKg: 5.8, expectedGrowthPerDayMin: 0.100, expectedGrowthPerDayMax: 0.140, expectedWeightGainPerDayMin: 0.03000, expectedWeightGainPerDayMax: 0.05000),
  GrowthCurvePoint(ageMonths: 2, ageDays: 61, minHeightCm: 54.4, avgHeightCm: 58.4, maxHeightCm: 62.4, minWeightKg: 4.3, avgWeightKg: 5.6, maxWeightKg: 7.0, expectedGrowthPerDayMin: 0.100, expectedGrowthPerDayMax: 0.140, expectedWeightGainPerDayMin: 0.02903, expectedWeightGainPerDayMax: 0.03871),
  GrowthCurvePoint(ageMonths: 3, ageDays: 91, minHeightCm: 57.3, avgHeightCm: 61.4, maxHeightCm: 65.5, minWeightKg: 5.0, avgWeightKg: 6.4, maxWeightKg: 7.9, expectedGrowthPerDayMin: 0.060, expectedGrowthPerDayMax: 0.090, expectedWeightGainPerDayMin: 0.02333, expectedWeightGainPerDayMax: 0.03000),
  GrowthCurvePoint(ageMonths: 4, ageDays: 122, minHeightCm: 59.7, avgHeightCm: 63.9, maxHeightCm: 68.0, minWeightKg: 5.6, avgWeightKg: 7.0, maxWeightKg: 8.6, expectedGrowthPerDayMin: 0.060, expectedGrowthPerDayMax: 0.090, expectedWeightGainPerDayMin: 0.01935, expectedWeightGainPerDayMax: 0.02258),
  GrowthCurvePoint(ageMonths: 5, ageDays: 152, minHeightCm: 61.7, avgHeightCm: 65.9, maxHeightCm: 70.1, minWeightKg: 6.0, avgWeightKg: 7.5, maxWeightKg: 9.2, expectedGrowthPerDayMin: 0.060, expectedGrowthPerDayMax: 0.090, expectedWeightGainPerDayMin: 0.01333, expectedWeightGainPerDayMax: 0.02000),
  GrowthCurvePoint(ageMonths: 6, ageDays: 183, minHeightCm: 63.3, avgHeightCm: 67.6, maxHeightCm: 71.9, minWeightKg: 6.4, avgWeightKg: 7.9, maxWeightKg: 9.7, expectedGrowthPerDayMin: 0.040, expectedGrowthPerDayMax: 0.050, expectedWeightGainPerDayMin: 0.01290, expectedWeightGainPerDayMax: 0.01613),
  GrowthCurvePoint(ageMonths: 7, ageDays: 213, minHeightCm: 64.8, avgHeightCm: 69.2, maxHeightCm: 73.5, minWeightKg: 6.7, avgWeightKg: 8.3, maxWeightKg: 10.2, expectedGrowthPerDayMin: 0.040, expectedGrowthPerDayMax: 0.050, expectedWeightGainPerDayMin: 0.01000, expectedWeightGainPerDayMax: 0.01667),
  GrowthCurvePoint(ageMonths: 8, ageDays: 244, minHeightCm: 66.2, avgHeightCm: 70.6, maxHeightCm: 75.0, minWeightKg: 6.9, avgWeightKg: 8.6, maxWeightKg: 10.6, expectedGrowthPerDayMin: 0.040, expectedGrowthPerDayMax: 0.050, expectedWeightGainPerDayMin: 0.00645, expectedWeightGainPerDayMax: 0.01290),
  GrowthCurvePoint(ageMonths: 9, ageDays: 274, minHeightCm: 67.5, avgHeightCm: 72.0, maxHeightCm: 76.5, minWeightKg: 7.1, avgWeightKg: 8.9, maxWeightKg: 11.0, expectedGrowthPerDayMin: 0.040, expectedGrowthPerDayMax: 0.050, expectedWeightGainPerDayMin: 0.00667, expectedWeightGainPerDayMax: 0.01333),
  GrowthCurvePoint(ageMonths: 10, ageDays: 304, minHeightCm: 68.7, avgHeightCm: 73.3, maxHeightCm: 77.9, minWeightKg: 7.4, avgWeightKg: 9.2, maxWeightKg: 11.4, expectedGrowthPerDayMin: 0.040, expectedGrowthPerDayMax: 0.050, expectedWeightGainPerDayMin: 0.01000, expectedWeightGainPerDayMax: 0.01333),
  GrowthCurvePoint(ageMonths: 11, ageDays: 335, minHeightCm: 69.9, avgHeightCm: 74.5, maxHeightCm: 79.2, minWeightKg: 7.6, avgWeightKg: 9.4, maxWeightKg: 11.7, expectedGrowthPerDayMin: 0.040, expectedGrowthPerDayMax: 0.050, expectedWeightGainPerDayMin: 0.00645, expectedWeightGainPerDayMax: 0.00968),
  GrowthCurvePoint(ageMonths: 12, ageDays: 365, minHeightCm: 71.0, avgHeightCm: 75.7, maxHeightCm: 80.5, minWeightKg: 7.8, avgWeightKg: 9.6, maxWeightKg: 12.0, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.040, expectedWeightGainPerDayMin: 0.00667, expectedWeightGainPerDayMax: 0.01000),
  GrowthCurvePoint(ageMonths: 13, ageDays: 396, minHeightCm: 72.0, avgHeightCm: 76.8, maxHeightCm: 81.8, minWeightKg: 7.969398907103825, avgWeightKg: 9.820218579234972, maxWeightKg: 12.287978142076502, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.040, expectedWeightGainPerDayMin: 0.00546, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 14, ageDays: 426, minHeightCm: 73.0, avgHeightCm: 77.9, maxHeightCm: 83.0, minWeightKg: 8.133333333333333, avgWeightKg: 10.033333333333333, maxWeightKg: 12.566666666666666, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.040, expectedWeightGainPerDayMin: 0.00546, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 15, ageDays: 457, minHeightCm: 74.0, avgHeightCm: 79.0, maxHeightCm: 84.2, minWeightKg: 8.302732240437159, avgWeightKg: 10.253551912568305, maxWeightKg: 12.854644808743169, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.040, expectedWeightGainPerDayMin: 0.00546, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 16, ageDays: 487, minHeightCm: 74.9, avgHeightCm: 80.1, maxHeightCm: 85.5, minWeightKg: 8.466666666666667, avgWeightKg: 10.466666666666667, maxWeightKg: 13.133333333333333, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.040, expectedWeightGainPerDayMin: 0.00546, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 17, ageDays: 517, minHeightCm: 75.9, avgHeightCm: 81.2, maxHeightCm: 86.8, minWeightKg: 8.630601092896175, avgWeightKg: 10.679781420765028, maxWeightKg: 13.412021857923497, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.040, expectedWeightGainPerDayMin: 0.00546, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 18, ageDays: 548, minHeightCm: 76.9, avgHeightCm: 82.3, maxHeightCm: 88.0, minWeightKg: 8.8, avgWeightKg: 10.9, maxWeightKg: 13.7, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.040, expectedWeightGainPerDayMin: 0.00546, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 19, ageDays: 578, minHeightCm: 77.7, avgHeightCm: 83.2, maxHeightCm: 89.1, minWeightKg: 8.948351648351649, avgWeightKg: 11.114285714285714, maxWeightKg: 13.963736263736264, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.040, expectedWeightGainPerDayMin: 0.00495, expectedWeightGainPerDayMax: 0.00879),
  GrowthCurvePoint(ageMonths: 20, ageDays: 609, minHeightCm: 78.4, avgHeightCm: 84.1, maxHeightCm: 90.2, minWeightKg: 9.101648351648352, avgWeightKg: 11.335714285714285, maxWeightKg: 14.236263736263735, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.040, expectedWeightGainPerDayMin: 0.00495, expectedWeightGainPerDayMax: 0.00879),
  GrowthCurvePoint(ageMonths: 21, ageDays: 639, minHeightCm: 79.2, avgHeightCm: 85.0, maxHeightCm: 91.3, minWeightKg: 9.25, avgWeightKg: 11.55, maxWeightKg: 14.5, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.040, expectedWeightGainPerDayMin: 0.00495, expectedWeightGainPerDayMax: 0.00879),
  GrowthCurvePoint(ageMonths: 22, ageDays: 670, minHeightCm: 80.0, avgHeightCm: 86.0, maxHeightCm: 92.5, minWeightKg: 9.403296703296704, avgWeightKg: 11.77142857142857, maxWeightKg: 14.772527472527473, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.040, expectedWeightGainPerDayMin: 0.00495, expectedWeightGainPerDayMax: 0.00879),
  GrowthCurvePoint(ageMonths: 23, ageDays: 700, minHeightCm: 80.7, avgHeightCm: 86.9, maxHeightCm: 93.6, minWeightKg: 9.551648351648351, avgWeightKg: 11.985714285714286, maxWeightKg: 15.036263736263736, expectedGrowthPerDayMin: 0.025, expectedGrowthPerDayMax: 0.040, expectedWeightGainPerDayMin: 0.00495, expectedWeightGainPerDayMax: 0.00879),
  GrowthCurvePoint(ageMonths: 24, ageDays: 730, minHeightCm: 81.5, avgHeightCm: 87.8, maxHeightCm: 94.7, minWeightKg: 9.7, avgWeightKg: 12.2, maxWeightKg: 15.3, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00495, expectedWeightGainPerDayMax: 0.00879),
  GrowthCurvePoint(ageMonths: 25, ageDays: 761, minHeightCm: 82.1, avgHeightCm: 88.5, maxHeightCm: 95.4, minWeightKg: 9.83551912568306, avgWeightKg: 12.386338797814208, maxWeightKg: 15.587978142076503, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 26, ageDays: 791, minHeightCm: 82.6, avgHeightCm: 89.2, maxHeightCm: 96.1, minWeightKg: 9.966666666666667, avgWeightKg: 12.566666666666666, maxWeightKg: 15.866666666666667, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 27, ageDays: 822, minHeightCm: 83.2, avgHeightCm: 89.8, maxHeightCm: 96.8, minWeightKg: 10.102185792349726, avgWeightKg: 12.753005464480875, maxWeightKg: 16.15464480874317, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 28, ageDays: 852, minHeightCm: 83.8, avgHeightCm: 90.5, maxHeightCm: 97.6, minWeightKg: 10.233333333333333, avgWeightKg: 12.933333333333334, maxWeightKg: 16.433333333333334, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 29, ageDays: 883, minHeightCm: 84.3, avgHeightCm: 91.2, maxHeightCm: 98.3, minWeightKg: 10.368852459016393, avgWeightKg: 13.119672131147542, maxWeightKg: 16.721311475409838, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 30, ageDays: 913, minHeightCm: 84.9, avgHeightCm: 91.9, maxHeightCm: 99.0, minWeightKg: 10.5, avgWeightKg: 13.3, maxWeightKg: 17.0, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00929),
  GrowthCurvePoint(ageMonths: 31, ageDays: 944, minHeightCm: 85.5, avgHeightCm: 92.6, maxHeightCm: 99.8, minWeightKg: 10.63551912568306, avgWeightKg: 13.469398907103827, maxWeightKg: 17.220218579234974, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00710),
  GrowthCurvePoint(ageMonths: 32, ageDays: 974, minHeightCm: 86.2, avgHeightCm: 93.3, maxHeightCm: 100.6, minWeightKg: 10.766666666666667, avgWeightKg: 13.633333333333335, maxWeightKg: 17.433333333333334, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00710),
  GrowthCurvePoint(ageMonths: 33, ageDays: 1004, minHeightCm: 86.8, avgHeightCm: 94.0, maxHeightCm: 101.4, minWeightKg: 10.897814207650274, avgWeightKg: 13.797267759562843, maxWeightKg: 17.646448087431693, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00710),
  GrowthCurvePoint(ageMonths: 34, ageDays: 1035, minHeightCm: 87.4, avgHeightCm: 94.7, maxHeightCm: 102.2, minWeightKg: 11.033333333333333, avgWeightKg: 13.966666666666667, maxWeightKg: 17.866666666666667, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00710),
  GrowthCurvePoint(ageMonths: 35, ageDays: 1065, minHeightCm: 88.1, avgHeightCm: 95.4, maxHeightCm: 103.0, minWeightKg: 11.16448087431694, avgWeightKg: 14.130601092896175, maxWeightKg: 18.079781420765027, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00710),
  GrowthCurvePoint(ageMonths: 36, ageDays: 1096, minHeightCm: 88.7, avgHeightCm: 96.1, maxHeightCm: 103.8, minWeightKg: 11.3, avgWeightKg: 14.3, maxWeightKg: 18.3, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00437, expectedWeightGainPerDayMax: 0.00710),
  GrowthCurvePoint(ageMonths: 37, ageDays: 1126, minHeightCm: 89.2, avgHeightCm: 96.7, maxHeightCm: 104.5, minWeightKg: 11.415068493150686, avgWeightKg: 14.464383561643837, maxWeightKg: 18.53835616438356, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00384, expectedWeightGainPerDayMax: 0.00795),
  GrowthCurvePoint(ageMonths: 38, ageDays: 1157, minHeightCm: 89.8, avgHeightCm: 97.3, maxHeightCm: 105.1, minWeightKg: 11.533972602739727, avgWeightKg: 14.634246575342466, maxWeightKg: 18.784657534246577, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00384, expectedWeightGainPerDayMax: 0.00795),
  GrowthCurvePoint(ageMonths: 39, ageDays: 1187, minHeightCm: 90.3, avgHeightCm: 97.9, maxHeightCm: 105.8, minWeightKg: 11.64904109589041, avgWeightKg: 14.798630136986302, maxWeightKg: 19.023013698630137, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00384, expectedWeightGainPerDayMax: 0.00795),
  GrowthCurvePoint(ageMonths: 40, ageDays: 1218, minHeightCm: 90.8, avgHeightCm: 98.5, maxHeightCm: 106.4, minWeightKg: 11.767945205479453, avgWeightKg: 14.968493150684932, maxWeightKg: 19.26931506849315, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00384, expectedWeightGainPerDayMax: 0.00795),
  GrowthCurvePoint(ageMonths: 41, ageDays: 1248, minHeightCm: 91.4, avgHeightCm: 99.1, maxHeightCm: 107.1, minWeightKg: 11.883013698630137, avgWeightKg: 15.132876712328768, maxWeightKg: 19.507671232876714, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00384, expectedWeightGainPerDayMax: 0.00795),
  GrowthCurvePoint(ageMonths: 42, ageDays: 1278, minHeightCm: 91.9, avgHeightCm: 99.7, maxHeightCm: 107.8, minWeightKg: 11.998082191780822, avgWeightKg: 15.297260273972604, maxWeightKg: 19.746027397260274, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00384, expectedWeightGainPerDayMax: 0.00795),
  GrowthCurvePoint(ageMonths: 43, ageDays: 1309, minHeightCm: 92.4, avgHeightCm: 100.3, maxHeightCm: 108.4, minWeightKg: 12.116986301369863, avgWeightKg: 15.467123287671233, maxWeightKg: 19.992328767123286, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00384, expectedWeightGainPerDayMax: 0.00795),
  GrowthCurvePoint(ageMonths: 44, ageDays: 1339, minHeightCm: 93.0, avgHeightCm: 100.9, maxHeightCm: 109.1, minWeightKg: 12.232054794520547, avgWeightKg: 15.63150684931507, maxWeightKg: 20.23068493150685, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00384, expectedWeightGainPerDayMax: 0.00795),
  GrowthCurvePoint(ageMonths: 45, ageDays: 1370, minHeightCm: 93.5, avgHeightCm: 101.5, maxHeightCm: 109.7, minWeightKg: 12.35095890410959, avgWeightKg: 15.801369863013699, maxWeightKg: 20.476986301369863, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00384, expectedWeightGainPerDayMax: 0.00795),
  GrowthCurvePoint(ageMonths: 46, ageDays: 1400, minHeightCm: 94.0, avgHeightCm: 102.1, maxHeightCm: 110.4, minWeightKg: 12.466027397260273, avgWeightKg: 15.965753424657535, maxWeightKg: 20.715342465753423, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00384, expectedWeightGainPerDayMax: 0.00795),
  GrowthCurvePoint(ageMonths: 47, ageDays: 1431, minHeightCm: 94.6, avgHeightCm: 102.7, maxHeightCm: 111.0, minWeightKg: 12.584931506849314, avgWeightKg: 16.135616438356166, maxWeightKg: 20.96164383561644, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00384, expectedWeightGainPerDayMax: 0.00795),
  GrowthCurvePoint(ageMonths: 48, ageDays: 1461, minHeightCm: 95.1, avgHeightCm: 103.3, maxHeightCm: 111.7, minWeightKg: 12.7, avgWeightKg: 16.3, maxWeightKg: 21.2, expectedGrowthPerDayMin: 0.018, expectedGrowthPerDayMax: 0.028, expectedWeightGainPerDayMin: 0.00384, expectedWeightGainPerDayMax: 0.00795),
];
class GrowthCurves {
  GrowthCurves._();

  static GrowthCurveSex sexFromProfile(String? sex) {
    final sx = sex?.trim().toUpperCase();
    if (sx == 'M') return GrowthCurveSex.male;
    return GrowthCurveSex.female;
  }

  static List<GrowthCurvePoint> curveFor(GrowthCurveSex sex) =>
      sex == GrowthCurveSex.male ? boysGrowthCurve : girlsGrowthCurve;

  /// Linear interpolation by [ageDays] between table knots.
  static GrowthCurvePoint interpolate(
    List<GrowthCurvePoint> curve,
    int ageDays,
  ) {
    if (curve.isEmpty) {
      throw ArgumentError('curve must not be empty');
    }
    if (ageDays <= curve.first.ageDays) return curve.first;
    if (ageDays >= curve.last.ageDays) return curve.last;
    for (var i = 0; i < curve.length - 1; i++) {
      final a = curve[i];
      final b = curve[i + 1];
      if (ageDays >= a.ageDays && ageDays <= b.ageDays) {
        final span = (b.ageDays - a.ageDays).toDouble();
        final t = span <= 0 ? 0.0 : (ageDays - a.ageDays) / span;
        double lerp(double x, double y) => x + (y - x) * t;
        return GrowthCurvePoint(
          ageMonths: ((a.ageMonths + (b.ageMonths - a.ageMonths) * t).round()),
          ageDays: ageDays,
          minHeightCm: lerp(a.minHeightCm, b.minHeightCm),
          avgHeightCm: lerp(a.avgHeightCm, b.avgHeightCm),
          maxHeightCm: lerp(a.maxHeightCm, b.maxHeightCm),
          minWeightKg: lerp(a.minWeightKg, b.minWeightKg),
          avgWeightKg: lerp(a.avgWeightKg, b.avgWeightKg),
          maxWeightKg: lerp(a.maxWeightKg, b.maxWeightKg),
          expectedGrowthPerDayMin:
              lerp(a.expectedGrowthPerDayMin, b.expectedGrowthPerDayMin),
          expectedGrowthPerDayMax:
              lerp(a.expectedGrowthPerDayMax, b.expectedGrowthPerDayMax),
          expectedWeightGainPerDayMin: lerp(
            a.expectedWeightGainPerDayMin,
            b.expectedWeightGainPerDayMin,
          ),
          expectedWeightGainPerDayMax: lerp(
            a.expectedWeightGainPerDayMax,
            b.expectedWeightGainPerDayMax,
          ),
        );
      }
    }
    return curve.last;
  }

  static int ageDaysFromBirth(DateTime birth, DateTime measured) {
    final b = DateTime(birth.year, birth.month, birth.day);
    final m = DateTime(measured.year, measured.month, measured.day);
    return m.difference(b).inDays;
  }
}
