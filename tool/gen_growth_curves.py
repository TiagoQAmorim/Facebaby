# Generates lib/data/growth_curves.dart (height + weight reference tables).

# Height: ageMonths ageDays minH avgH maxH growthMinDay growthMaxDay
girls_height = """0 0 45.4 49.1 52.9 0.090 0.130
1 30 49.8 53.7 57.6 0.090 0.130
2 61 53.0 57.1 61.1 0.090 0.130
3 91 55.6 59.8 64.0 0.060 0.080
4 122 57.8 62.1 66.4 0.060 0.080
5 152 59.6 64.0 68.5 0.060 0.080
6 183 61.2 65.7 70.3 0.030 0.050
7 213 62.7 67.3 72.1 0.030 0.050
8 244 64.0 68.7 73.7 0.030 0.050
9 274 65.3 70.1 75.3 0.030 0.050
10 304 66.5 71.5 76.8 0.030 0.050
11 335 67.7 72.8 78.3 0.030 0.050
12 365 68.9 74.0 79.8 0.025 0.035
13 396 69.8 75.1 81.1 0.025 0.035
14 426 70.6 76.2 82.4 0.025 0.035
15 457 71.5 77.3 83.7 0.025 0.035
16 487 72.3 78.5 84.9 0.025 0.035
17 517 73.2 79.6 86.2 0.025 0.035
18 548 74.0 80.7 87.5 0.025 0.035
19 578 74.9 81.7 88.6 0.025 0.035
20 609 75.8 82.6 89.6 0.025 0.035
21 639 76.7 83.6 90.7 0.025 0.035
22 670 77.6 84.5 91.8 0.025 0.035
23 700 78.5 85.5 92.8 0.025 0.035
24 730 79.4 86.4 93.9 0.015 0.025
25 761 79.9 87.0 94.5 0.015 0.025
26 791 80.4 87.6 95.1 0.015 0.025
27 822 81.0 88.2 95.7 0.015 0.025
28 852 81.5 88.8 96.3 0.015 0.025
29 883 82.0 89.4 96.9 0.015 0.025
30 913 82.5 90.0 97.5 0.015 0.025
31 944 83.2 90.8 98.5 0.015 0.025
32 974 84.0 91.7 99.4 0.015 0.025
33 1004 84.8 92.5 100.4 0.015 0.025
34 1035 85.5 93.4 101.4 0.015 0.025
35 1065 86.2 94.2 102.3 0.015 0.025
36 1096 87.0 95.1 103.3 0.015 0.025
37 1126 87.6 95.7 104.0 0.015 0.025
38 1157 88.2 96.4 104.6 0.015 0.025
39 1187 88.8 97.0 105.3 0.015 0.025
40 1218 89.3 97.6 106.0 0.015 0.025
41 1248 89.9 98.3 106.6 0.015 0.025
42 1278 90.5 98.9 107.3 0.015 0.025
43 1309 91.1 99.5 108.0 0.015 0.025
44 1339 91.7 100.2 108.6 0.015 0.025
45 1370 92.2 100.8 109.3 0.015 0.025
46 1400 92.8 101.4 110.0 0.015 0.025
47 1431 93.4 102.1 110.6 0.015 0.025
48 1461 94.0 102.7 111.3 0.015 0.025"""

boys_height = """0 0 46.1 49.9 53.7 0.100 0.140
1 30 50.8 54.7 58.6 0.100 0.140
2 61 54.4 58.4 62.4 0.100 0.140
3 91 57.3 61.4 65.5 0.060 0.090
4 122 59.7 63.9 68.0 0.060 0.090
5 152 61.7 65.9 70.1 0.060 0.090
6 183 63.3 67.6 71.9 0.040 0.050
7 213 64.8 69.2 73.5 0.040 0.050
8 244 66.2 70.6 75.0 0.040 0.050
9 274 67.5 72.0 76.5 0.040 0.050
10 304 68.7 73.3 77.9 0.040 0.050
11 335 69.9 74.5 79.2 0.040 0.050
12 365 71.0 75.7 80.5 0.025 0.040
13 396 72.0 76.8 81.8 0.025 0.040
14 426 73.0 77.9 83.0 0.025 0.040
15 457 74.0 79.0 84.2 0.025 0.040
16 487 74.9 80.1 85.5 0.025 0.040
17 517 75.9 81.2 86.8 0.025 0.040
18 548 76.9 82.3 88.0 0.025 0.040
19 578 77.7 83.2 89.1 0.025 0.040
20 609 78.4 84.1 90.2 0.025 0.040
21 639 79.2 85.0 91.3 0.025 0.040
22 670 80.0 86.0 92.5 0.025 0.040
23 700 80.7 86.9 93.6 0.025 0.040
24 730 81.5 87.8 94.7 0.018 0.028
25 761 82.1 88.5 95.4 0.018 0.028
26 791 82.6 89.2 96.1 0.018 0.028
27 822 83.2 89.8 96.8 0.018 0.028
28 852 83.8 90.5 97.6 0.018 0.028
29 883 84.3 91.2 98.3 0.018 0.028
30 913 84.9 91.9 99.0 0.018 0.028
31 944 85.5 92.6 99.8 0.018 0.028
32 974 86.2 93.3 100.6 0.018 0.028
33 1004 86.8 94.0 101.4 0.018 0.028
34 1035 87.4 94.7 102.2 0.018 0.028
35 1065 88.1 95.4 103.0 0.018 0.028
36 1096 88.7 96.1 103.8 0.018 0.028
37 1126 89.2 96.7 104.5 0.018 0.028
38 1157 89.8 97.3 105.1 0.018 0.028
39 1187 90.3 97.9 105.8 0.018 0.028
40 1218 90.8 98.5 106.4 0.018 0.028
41 1248 91.4 99.1 107.1 0.018 0.028
42 1278 91.9 99.7 107.8 0.018 0.028
43 1309 92.4 100.3 108.4 0.018 0.028
44 1339 93.0 100.9 109.1 0.018 0.028
45 1370 93.5 101.5 109.7 0.018 0.028
46 1400 94.0 102.1 110.4 0.018 0.028
47 1431 94.6 102.7 111.0 0.018 0.028
48 1461 95.1 103.3 111.7 0.018 0.028"""

# Weight (FaceBaby PDF): ageMonths ageDays minKg avgKg maxKg
girls_weight = """0 0 2.4 3.2 4.2
1 30 3.2 4.2 5.5
2 61 4.0 5.1 6.6
3 91 4.6 5.8 7.4
4 122 5.1 6.4 8.1
5 152 5.5 6.9 8.7
6 183 5.8 7.3 9.2
7 213 6.1 7.6 9.6
8 244 6.3 7.9 10.0
9 274 6.5 8.2 10.4
10 304 6.7 8.5 10.8
11 335 6.9 8.7 11.1
12 365 7.0 8.9 11.5
18 548 8.1 10.2 13.0
24 730 9.0 11.5 14.8
30 913 10.0 12.8 16.5
36 1096 10.8 14.0 18.1
48 1461 12.0 16.1 21.5"""

boys_weight = """0 0 2.5 3.3 4.3
1 30 3.4 4.5 5.8
2 61 4.3 5.6 7.0
3 91 5.0 6.4 7.9
4 122 5.6 7.0 8.6
5 152 6.0 7.5 9.2
6 183 6.4 7.9 9.7
7 213 6.7 8.3 10.2
8 244 6.9 8.6 10.6
9 274 7.1 8.9 11.0
10 304 7.4 9.2 11.4
11 335 7.6 9.4 11.7
12 365 7.8 9.6 12.0
18 548 8.8 10.9 13.7
24 730 9.7 12.2 15.3
30 913 10.5 13.3 17.0
36 1096 11.3 14.3 18.3
48 1461 12.7 16.3 21.2"""


def parse_weight_table(text):
    out = {}
    for line in text.strip().split("\n"):
        m, d, mn, av, mx = line.split()
        out[int(d)] = (float(mn), float(av), float(mx))
    return out


def lerp(a, b, t):
    return a + (b - a) * t


def weight_at(weight_by_days, age_days):
    keys = sorted(weight_by_days.keys())
    if age_days <= keys[0]:
        return weight_by_days[keys[0]]
    if age_days >= keys[-1]:
        return weight_by_days[keys[-1]]
    for i in range(len(keys) - 1):
        d0, d1 = keys[i], keys[i + 1]
        if d0 <= age_days <= d1:
            w0, w1 = weight_by_days[d0], weight_by_days[d1]
            t = (age_days - d0) / (d1 - d0) if d1 != d0 else 0.0
            return (
                lerp(w0[0], w1[0], t),
                lerp(w0[1], w1[1], t),
                lerp(w0[2], w1[2], t),
            )
    return weight_by_days[keys[-1]]


def weight_velocity_at(weight_by_days, age_days):
    keys = sorted(weight_by_days.keys())
    if age_days <= keys[0]:
        d0, d1 = keys[0], keys[1]
    elif age_days >= keys[-1]:
        d0, d1 = keys[-2], keys[-1]
    else:
        for i in range(len(keys) - 1):
            if keys[i] <= age_days <= keys[i + 1]:
                d0, d1 = keys[i], keys[i + 1]
                break
    w0, w1 = weight_by_days[d0], weight_by_days[d1]
    span = max(d1 - d0, 1)
    return ((w1[0] - w0[0]) / span, (w1[2] - w0[2]) / span)


def emit_list(name, height_rows, weight_by_days):
    lines = [f"const List<GrowthCurvePoint> {name} = ["]
    for line in height_rows.strip().split("\n"):
        m, d, hmn, hav, hmx, gmn, gmx = line.split()
        d = int(d)
        wmn, wav, wmx = weight_at(weight_by_days, d)
        wvmin, wvmax = weight_velocity_at(weight_by_days, d)
        lines.append(
            f"  GrowthCurvePoint("
            f"ageMonths: {m}, ageDays: {d}, "
            f"minHeightCm: {hmn}, avgHeightCm: {hav}, maxHeightCm: {hmx}, "
            f"minWeightKg: {wmn}, avgWeightKg: {wav}, maxWeightKg: {wmx}, "
            f"expectedGrowthPerDayMin: {gmn}, expectedGrowthPerDayMax: {gmx}, "
            f"expectedWeightGainPerDayMin: {wvmin:.5f}, "
            f"expectedWeightGainPerDayMax: {wvmax:.5f}),"
        )
    lines.append("];")
    return "\n".join(lines)


header = """// Reference growth curves (height + weight, FaceBaby / WHO-inspired tables).

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

"""

footer = """
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
"""

girls_w = parse_weight_table(girls_weight)
boys_w = parse_weight_table(boys_weight)

out = (
    header
    + emit_list("girlsGrowthCurve", girls_height, girls_w)
    + "\n\n"
    + emit_list("boysGrowthCurve", boys_height, boys_w)
    + footer
)
with open("lib/data/growth_curves.dart", "w", encoding="utf-8") as f:
    f.write(out)
print("wrote lib/data/growth_curves.dart", len(out), "bytes")
