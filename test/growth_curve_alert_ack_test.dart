import 'package:facebaby_flutter/services/growth_analyzer_service.dart';
import 'package:facebaby_flutter/services/growth_curve_alert_ack.dart';
import 'package:facebaby_flutter/services/growth_curve_alert_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('não repete alerta para a mesma medição', () async {
    const babyId = 42;
    const item = GrowthCurveOutOfBand(
      kind: 'height',
      band: GrowthReferenceBand.aboveHealthyMax,
      value: 89,
      recordId: 7,
      refMin: 52.5,
      refMax: 60.5,
      ageMonths: 2,
    );

    expect(
      await GrowthCurveAlertAck.shouldNotify(
        babyId: babyId,
        signature: item.signature,
      ),
      isTrue,
    );

    await GrowthCurveAlertAck.markNotified(
      babyId: babyId,
      signature: item.signature,
    );

    expect(
      await GrowthCurveAlertAck.shouldNotify(
        babyId: babyId,
        signature: item.signature,
      ),
      isFalse,
    );
  });

  test('alerta de novo quando muda o registro de altura', () async {
    const babyId = 7;
    const oldItem = GrowthCurveOutOfBand(
      kind: 'height',
      band: GrowthReferenceBand.aboveHealthyMax,
      value: 89,
      recordId: 1,
      refMin: 52.5,
      refMax: 60.5,
      ageMonths: 2,
    );
    const newItem = GrowthCurveOutOfBand(
      kind: 'height',
      band: GrowthReferenceBand.aboveHealthyMax,
      value: 90,
      recordId: 2,
      refMin: 52.5,
      refMax: 60.5,
      ageMonths: 2,
    );

    await GrowthCurveAlertAck.markNotified(
      babyId: babyId,
      signature: oldItem.signature,
    );

    final pending = await GrowthCurveAlertAck.filterPending(
      babyId: babyId,
      items: [newItem],
    );
    expect(pending, hasLength(1));
    expect(pending.first.recordId, 2);
  });
}
