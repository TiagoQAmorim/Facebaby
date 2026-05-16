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
  return switch (pt) {
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
    _ => ZodiacId.sagittarius,
  };
}
