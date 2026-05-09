class DevelopmentLeap {
  /// Chave para textos traduzidos do banner (home/lista/pré-visualização): [S.developmentLeapBanner*].
  final String bannerKey;

  /// Label curto para UI legada/detalhes (mantido em PT no serviço).
  final String rangeLabel;

  /// Título do banner (ex.: "Primeira adaptação").
  final String homeTitle;

  /// Linha do banner (ex.: "<baby_name> pode estar...").
  final String homeLead;

  /// Bullets do banner (3–5 itens).
  final List<String> homeBullets;

  /// Frase emocional curta (💜 ...).
  final String emotional;

  /// Seções detalhadas.
  final String detailsWhatsHappening;
  final List<String> keywords;
  final List<String> whatMayHappen;
  final List<String> howToHelp;
  final List<String> skillsPossible;
  final String emotionalLook;

  /// Intervalo aproximado de idade em dias (inclusive), para escolher a fase atual.
  final int minAgeDays;
  final int maxAgeDays;

  const DevelopmentLeap({
    required this.bannerKey,
    required this.rangeLabel,
    required this.homeTitle,
    required this.homeLead,
    required this.homeBullets,
    required this.emotional,
    required this.detailsWhatsHappening,
    required this.keywords,
    required this.whatMayHappen,
    required this.howToHelp,
    required this.skillsPossible,
    required this.emotionalLook,
    required this.minAgeDays,
    required this.maxAgeDays,
  });
}

