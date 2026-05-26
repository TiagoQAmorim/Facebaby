import 'zodiac.dart';

/// Identificador interno do signo (independente do idioma de exibição).
enum ZodiacId {
  capricorn,
  aquarius,
  pisces,
  aries,
  taurus,
  gemini,
  cancer,
  leo,
  virgo,
  libra,
  scorpio,
  sagittarius,
}

ZodiacId zodiacIdFromDate(DateTime date) {
  final pt = zodiacSignPtBr(date);
  return zodiacIdFromSignLabel(pt) ?? ZodiacId.sagittarius;
}

String _foldSignLabel(String label) {
  return label
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');
}

/// Converte rótulo de signo (PT/EN/ES/…) em [ZodiacId] para ícones em `assets/family/`.
ZodiacId? zodiacIdFromSignLabel(String? label) {
  final raw = '${label ?? ''}'.trim();
  if (raw.isEmpty) return null;

  final n = _foldSignLabel(raw);
  if (n.contains('nao informado') ||
      n.contains('not informed') ||
      n.contains('non renseigne') ||
      n == '?' ||
      n == '-') {
    return null;
  }

  if (n.contains('capric')) return ZodiacId.capricorn;
  if (n.contains('aquar')) return ZodiacId.aquarius;
  if (n.contains('peix') || n.contains('pisces') || n.contains('pisc')) {
    return ZodiacId.pisces;
  }
  if (n.contains('aries') || n.startsWith('ari')) return ZodiacId.aries;
  if (n.contains('touro') || n.contains('taurus') || n.contains('taureau')) {
    return ZodiacId.taurus;
  }
  if (n.contains('geme') || n.contains('gemini') || n.contains('gemeaux')) {
    return ZodiacId.gemini;
  }
  if (n.contains('cancer')) return ZodiacId.cancer;
  if (n.contains('leao') || n.contains('leon') || n == 'leo') return ZodiacId.leo;
  if (n.contains('virg')) return ZodiacId.virgo;
  if (n.contains('libra')) return ZodiacId.libra;
  if (n.contains('escorp') || n.contains('scorp')) return ZodiacId.scorpio;
  if (n.contains('sagit') || n.contains('sagitt')) return ZodiacId.sagittarius;

  return switch (raw) {
    'Capricórnio' => ZodiacId.capricorn,
    'Aquário' => ZodiacId.aquarius,
    'Peixes' => ZodiacId.pisces,
    'Áries' => ZodiacId.aries,
    'Touro' => ZodiacId.taurus,
    'Gêmeos' => ZodiacId.gemini,
    'Câncer' => ZodiacId.cancer,
    'Leão' => ZodiacId.leo,
    'Virgem' => ZodiacId.virgo,
    'Libra' => ZodiacId.libra,
    'Escorpião' => ZodiacId.scorpio,
    'Sagitário' => ZodiacId.sagittarius,
    _ => null,
  };
}
