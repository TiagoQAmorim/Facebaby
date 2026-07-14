import 'package:facebaby_flutter/services/premium/premium_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseLocalizedPriceAmount handles BR and US formats', () {
    expect(
      PremiumService.parseLocalizedPriceAmountForTest('R\$ 129,00'),
      closeTo(129.0, 0.001),
    );
    expect(
      PremiumService.parseLocalizedPriceAmountForTest('R\$ 15,90'),
      closeTo(15.90, 0.001),
    );
    expect(
      PremiumService.parseLocalizedPriceAmountForTest('US\$15.90'),
      closeTo(15.90, 0.001),
    );
    expect(
      PremiumService.parseLocalizedPriceAmountForTest('1.234,56'),
      closeTo(1234.56, 0.001),
    );
  });
}
