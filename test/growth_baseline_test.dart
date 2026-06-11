import 'package:facebaby_flutter/utils/growth_baseline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('birthWeightKg prefers birth_weight_kg over current weight_kg', () {
    expect(
      GrowthBaseline.birthWeightKg({
        'birth_weight_kg': 3.2,
        'weight_kg': 5.0,
      }),
      closeTo(3.2, 0.001),
    );
    expect(
      GrowthBaseline.birthWeightKg({'weight_kg': 4.1}),
      closeTo(4.1, 0.001),
    );
  });

  test('maxValueByMeasuredAt picks newest row', () {
    final rows = [
      {
        'measured_at': '2025-01-01T10:00:00.000',
        'value': 3.5,
      },
      {
        'measured_at': '2026-03-15T08:00:00.000',
        'value': 4.2,
      },
      {
        'measured_at': '2025-06-01T12:00:00.000',
        'value': 3.9,
      },
    ];
    final latest = GrowthBaseline.maxValueByMeasuredAtForTest(rows);
    expect(latest, closeTo(4.2, 0.001));
  });
}
