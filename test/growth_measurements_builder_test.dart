import 'package:facebaby_flutter/utils/growth_measurements_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final birth = DateTime(2025, 1, 1);

  test('weight curve keeps birth point when new measurements are added', () {
    final points = GrowthMeasurementsBuilder.weightFromRows(
      birthDate: birth,
      birthWeightKg: 3.2,
      weightRows: [
        {
          'measured_at': '2025-03-01T10:00:00.000',
          'value': 4.5,
        },
        {
          'measured_at': '2025-06-01T10:00:00.000',
          'value': 5.1,
        },
      ],
    );

    expect(points, isNotEmpty);
    expect(points.first.weightKg, closeTo(3.2, 0.001));
    expect(points.first.ageDays, 0);
    expect(points.map((p) => p.weightKg).whereType<double>().toList(), contains(4.5));
    expect(points.map((p) => p.weightKg).whereType<double>().toList(), contains(5.1));
  });

  test('height curve keeps birth point when new measurements are added', () {
    final points = GrowthMeasurementsBuilder.heightFromRows(
      birthDate: birth,
      birthHeightCm: 50.0,
      heightRows: [
        {
          'measured_at': '2025-04-01T10:00:00.000',
          'value': 62.0,
        },
      ],
    );

    expect(points.first.heightCm, closeTo(50.0, 0.001));
    expect(points.last.heightCm, closeTo(62.0, 0.001));
  });
}
