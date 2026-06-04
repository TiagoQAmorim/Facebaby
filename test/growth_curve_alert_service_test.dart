import 'package:flutter_test/flutter_test.dart';
import 'package:facebaby_flutter/data/growth_curves.dart';
import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/models/growth_measurement_point.dart';
import 'package:facebaby_flutter/services/growth_analyzer_service.dart';
import 'package:facebaby_flutter/services/growth_curve_alert_service.dart';

void main() {
  const analyzer = GrowthAnalyzerService();
  const strings = S(AppLang.pt);

  test('altura muito acima da curva é detectada pelo analisador', () {
    final birth = DateTime(2026, 3, 1);
    final at = birth.add(const Duration(days: 61));
    final result = analyzer.analyzeHeight(
      sex: GrowthCurveSex.female,
      measurements: [
        GrowthMeasurementPoint(
          measuredAt: at,
          ageDays: 61,
          heightCm: 83,
        ),
      ],
    );
    expect(result.referenceBand, GrowthReferenceBand.aboveHealthyMax);
    expect(result.referenceAtAge, isNotNull);
    expect(result.referenceAtAge!.maxHeightCm, lessThan(83));
  });

  test('prioridade do balão é mais urgente que peso em queda', () {
    const below = GrowthCurveOutOfBand(
      kind: 'weight',
      band: GrowthReferenceBand.belowHealthyMin,
      value: 3.0,
      recordId: 1,
      refMin: 4.0,
      refMax: 6.0,
      ageMonths: 2,
    );
    expect(
      GrowthCurveAlertService.bubblePriority(below),
      lessThan(60),
    );
  });

  test('texto do balão inclui valor e faixa de referência', () {
    const item = GrowthCurveOutOfBand(
      kind: 'height',
      band: GrowthReferenceBand.aboveHealthyMax,
      value: 83,
      recordId: 9,
      refMin: 53,
      refMax: 61,
      ageMonths: 2,
    );
    final text = GrowthCurveAlertService.bubbleText(
      item: item,
      babyName: 'Luna',
      strings: strings,
    );
    expect(text, contains('Luna'));
    expect(text, contains('83'));
    expect(text, contains('Urgente'));
  });
}
