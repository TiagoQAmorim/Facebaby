/// Visibilidade do banner “Foto da Semana” na Home (além da janela `draw_at`/`display_until`).
///
/// - `bypass_display_window` no Firestore (`spotlight_current`): definido pela Cloud Function no
///   **primeiro** sorteio com vencedor; sorteios seguintes voltam a obedecer à janela semanal.
/// - [kEmergencyBypassDisplayWindow]: só para emergência em release; preferir `false` quando o
///   backend estiver estável.
class WeeklyPhotoSpotlightConfig {
  WeeklyPhotoSpotlightConfig._();

  /// Quando true, ignora `draw_at`/`display_until` se existir destaque `active` com foto/título.
  /// Manter **false** em produção para não ficar preso a seeds antigos com foto de demonstração.
  static const bool kEmergencyBypassDisplayWindow = false;
}
