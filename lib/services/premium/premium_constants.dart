/// IDs e constantes do produto **único vitalício** nas lojas (non-consumable).
abstract final class PremiumConstants {
  PremiumConstants._();

  /// Fallback só quando [ProductDetails] ainda não chegou ou falhou.
  /// **Preço real:** Google Play / App Store aplicam preço regional via Billing — usar [PremiumService.formattedLocalizedPrice].
  static const String priceDisplayBr = 'R\$ 9,90';

  /// Mesmo SKU em Google Play (**Produto in-app gerido / managed**) e App Store Connect (Non-Consumable).
  ///
  /// Na Play Console: **Monetizar → Produtos in-app** — o **ID do produto** tem de coincidir exactamente
  /// (por defeito `facebaby_premium`). Para usar outro ID sem alterar código:
  /// `flutter build appbundle --dart-define=FACEBABY_PREMIUM_SKU=o_teu_id`
  static String get productIdLifetime {
    const fromEnv = String.fromEnvironment('FACEBABY_PREMIUM_SKU');
    return fromEnv.trim().isEmpty ? 'facebaby_premium' : fromEnv.trim();
  }

  /// Momentos com foto/texto no plano gratuito (selos).
  static const int freeMemoryMomentsMax = 8;
}
