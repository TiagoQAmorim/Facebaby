import 'zodiac_keys.dart';

enum ZodiacElement { fire, earth, air, water }

ZodiacElement zodiacElementFor(ZodiacId id) {
  switch (id) {
    case ZodiacId.aries:
    case ZodiacId.leo:
    case ZodiacId.sagittarius:
      return ZodiacElement.fire;
    case ZodiacId.taurus:
    case ZodiacId.virgo:
    case ZodiacId.capricorn:
      return ZodiacElement.earth;
    case ZodiacId.gemini:
    case ZodiacId.libra:
    case ZodiacId.aquarius:
      return ZodiacElement.air;
    case ZodiacId.cancer:
    case ZodiacId.scorpio:
    case ZodiacId.pisces:
      return ZodiacElement.water;
  }
}
