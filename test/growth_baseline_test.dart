import 'package:facebaby_flutter/utils/growth_baseline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
