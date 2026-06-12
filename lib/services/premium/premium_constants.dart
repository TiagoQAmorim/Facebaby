/// IDs e preços de referência do **FaceBaby Plus** (assinaturas + legado vitalício).
abstract final class PremiumConstants {
  PremiumConstants._();

  static const double monthlyPriceBr = 14.90;
  static const double annualPriceBr = 149.90;

  /// Fallback mensal quando a loja ainda não devolveu [ProductDetails].
  static const String priceDisplayMonthlyBr = 'R\$ 14,90/mês';

  /// Preço mensal da loja acima disso (BRL) costuma ser SKU errado (ex. anual no mensal).
  static const double monthlyStorePriceSanityMaxBr = 35.0;

  /// Fallback anual.
  static const String priceDisplayAnnualBr = 'R\$ 149,90/ano';

  /// Assinatura mensal — App Store Connect / Play Console.
  static const String productIdMonthly = 'facebaby_premium_monthly';

  /// Assinatura anual.
  static const String productIdAnnual = 'facebaby_premium_annual';

  /// Compra única antiga (restauração apenas; não consultar na loja).
  static const String productIdLifetimeLegacy = 'facebaby_premium';

  /// IDs pedidos ao StoreKit / Play Billing para novas assinaturas.
  static Set<String> get subscriptionProductIds => {
        productIdMonthly,
        productIdAnnual,
      };

  /// Todos os SKUs que concedem Plus (inclui legado vitalício em restauração).
  static Set<String> get allPremiumProductIds => {
        ...subscriptionProductIds,
        productIdLifetimeLegacy,
      };

  /// Economia do plano anual vs 12× mensal (valores de referência BR).
  static int get annualSavingsPercent {
    final yearlyIfMonthly = monthlyPriceBr * 12;
    if (yearlyIfMonthly <= 0) return 0;
    final saved = yearlyIfMonthly - annualPriceBr;
    return ((saved / yearlyIfMonthly) * 100).round().clamp(0, 99);
  }

  static String get annualSavingsAmountBr {
    final saved = (monthlyPriceBr * 12) - annualPriceBr;
    return saved.toStringAsFixed(2).replaceAll('.', ',');
  }

  static String get annualEquivalentMonthlyBr {
    final perMonth = annualPriceBr / 12;
    return perMonth.toStringAsFixed(2).replaceAll('.', ',');
  }

  /// Momentos com foto/texto no plano gratuito (selos).
  static const int freeMemoryMomentsMax = 4;
}
