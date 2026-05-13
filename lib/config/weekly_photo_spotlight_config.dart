/// Visibilidade do banner “Foto da Semana” na Home (além da janela `draw_at`/`display_until`).
///
/// - `bypass_display_window` no Firestore (`spotlight_current`): definido pela Cloud Function no
///   **primeiro** sorteio com vencedor; sorteios seguintes voltam a obedecer à janela semanal.
/// - [kEmergencyBypassDisplayWindow]: só para emergência em release; preferir `false` quando o
///   backend estiver estável.
/// - [kAllowStockSpotlightPhotoUrls]: build de teste; em produção prefira `winner_photo_url` real
///   (ex.: Firebase Storage) ou o campo Firestore `allow_stock_winner_photo` no próprio destaque.
class WeeklyPhotoSpotlightConfig {
  WeeklyPhotoSpotlightConfig._();

  /// Quando true, ignora `draw_at`/`display_until` se existir destaque `active` com foto/título.
  /// Manter **false** em produção para não ficar preso a seeds antigos com foto de demonstração.
  static const bool kEmergencyBypassDisplayWindow = false;

  /// Quando true (`--dart-define=ALLOW_STOCK_SPOTLIGHT_URLS=true`), aceita URLs de stock no
  /// banner (Unsplash, Picsum, etc.). **Não** usar em builds de loja com utilizadores reais.
  static const bool kAllowStockSpotlightPhotoUrls =
      bool.fromEnvironment('ALLOW_STOCK_SPOTLIGHT_URLS', defaultValue: false);
}
