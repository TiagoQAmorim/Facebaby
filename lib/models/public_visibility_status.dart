/// Estado de visibilidade pública da memória (Foto da Semana / mural seguro).
enum PublicVisibilityStatus {
  /// Predefinição: nada exposto a outras mães.
  private,

  /// Opt-in explícito; pode entrar no sorteio (se na janela Mon–Qui).
  public,

  /// Escolhida como vencedora da semana (sincronizado da nuvem).
  selected,

  /// Já não é exibida como destaque; opt-in pode estar off.
  expired,
}
