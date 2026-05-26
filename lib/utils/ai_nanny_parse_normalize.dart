import '../services/ai/ai_nanny_intent_lexicon.dart';

/// Normalização de números, horas e unidades (independente do idioma da frase).
abstract final class AiNannyParseNormalize {
  /// 37,5 / 37.5 / 37,5°C → 37.5
  static double? parseTemperatureCelsius(String text) {
    final low = text.toLowerCase();
    if (!AiNannyIntentLexicon.hasTemperatureCue(low) &&
        !RegExp(r'\d{2}[,.]\d').hasMatch(low)) {
      return null;
    }

    final patterns = [
      RegExp(
        r'(?:febre|fever|fiebre|fièvre|fieber|temperatura|temperature|temp)\s*[:.]?\s*(\d{1,2})(?:[,.](\d))?',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:está com|esta com|with|con|mit|avec|ha)\s*(\d{1,2})(?:[,.](\d))?',
        caseSensitive: false,
      ),
      RegExp(r'(\d{2})(?:[,.](\d))?\s*(?:°|graus|degrees|degrés|grados)?'),
    ];

    for (final re in patterns) {
      final m = re.firstMatch(low);
      if (m == null) continue;
      final v = _decimalFromMatch(m);
      if (v != null && v >= 35 && v <= 43) return v;
    }
    return null;
  }

  /// 10 minutos / 10 minutes / 10 Minuten / per 10 minuti → 10
  static int? parseDurationMinutes(String text) {
    final low = text.toLowerCase();
    final patterns = [
      RegExp(r'(\d{1,3})\s*(?:min(?:utos?|uti)?|minutes?|minuten)\b', caseSensitive: false),
      RegExp(
        r'(?:por|for|pendant|per|für|fuer|during)\s*(\d{1,3})\s*(?:min|m\b)',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d{1,3})\s*(?:min(?:utos?)?|minutes?|minuten)\s*(?:an der|on the|del|du|dal)',
        caseSensitive: false,
      ),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(low);
      if (m == null) continue;
      final n = int.tryParse(m.group(1)!);
      if (n != null && n > 0 && n <= 180) return n;
    }
    return null;
  }

  /// 14h, 14:00, 2pm, às 15h → HH:mm 24h
  static String? parseTime24h(String text) {
    final low = text.toLowerCase();

    var m = RegExp(
      r'(?:às|as|at|a las|alle|um|à)\s*(\d{1,2})(?::(\d{2}))?\s*(?:h)?',
      caseSensitive: false,
    ).firstMatch(low);
    if (m != null) return _hhmm(m.group(1)!, m.group(2));

    m = RegExp(r'(\d{1,2})[.:](\d{2})\s*(?:h)?').firstMatch(low);
    if (m != null) return _hhmm(m.group(1)!, m.group(2));

    m = RegExp(r'(\d{1,2})\s*h\b').firstMatch(low);
    if (m != null) return _hhmm(m.group(1)!, '0');

    m = RegExp(
      r'(\d{1,2})\s*(am|pm)\b',
      caseSensitive: false,
    ).firstMatch(low);
    if (m != null) {
      var h = int.parse(m.group(1)!);
      final pm = m.group(2)!.toLowerCase() == 'pm';
      if (pm && h < 12) h += 12;
      if (!pm && h == 12) h = 0;
      return '${h.toString().padLeft(2, '0')}:00';
    }
    return null;
  }

  static int? parseAmountMl(String text) {
    final m = RegExp(r'(\d{2,4})\s*ml\b', caseSensitive: false).firstMatch(text);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  static double? parseWeightKgTotal(String text) {
    final low = text.toLowerCase();
    if (!AiNannyIntentLexicon.containsAny(low, AiNannyIntentLexicon.weightCues) &&
        !low.contains('kg')) {
      return null;
    }
    final m = RegExp(
      r'(\d{1,2})(?:[,.](\d{1,3}))?\s*(?:kg|kilogram|kilograms|quilo|quilos)',
      caseSensitive: false,
    ).firstMatch(low);
    if (m == null) return null;
    final v = _decimalFromMatch(m);
    if (v == null || v <= 0 || v >= 35) return null;
    return v;
  }

  static int? parseWeightDeltaGrams(String text) {
    final low = text.toLowerCase();
    if (!AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.weightGainCues,
    )) {
      return null;
    }
    final m = RegExp(
      r'(\d{2,4})\s*(?:g|gramas?|grams?|grammes?|grammi|gramm)\b',
      caseSensitive: false,
    ).firstMatch(low);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  static double? parseHeightCmTotal(String text) {
    final low = text.toLowerCase();
    final m = RegExp(
      r'(\d{2,3})(?:[,.](\d))?\s*(?:cm|centimeter|centimetre|centimetri|zentimeter)',
      caseSensitive: false,
    ).firstMatch(low);
    if (m == null) return null;
    return _decimalFromMatch(m);
  }

  static double? parseHeightDeltaCm(String text) {
    final low = text.toLowerCase();
    if (!AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.heightGainCues,
    )) {
      return null;
    }
    final m = RegExp(
      r'(\d+(?:[,.]\d+)?)\s*(?:cm|centimeter|centimetre|centimetri)',
      caseSensitive: false,
    ).firstMatch(low);
    if (m == null) return null;
    return double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }

  static String? parseBreastSideCanonical(String text) {
    final low = text.toLowerCase();
    if (AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.breastBothCues,
    )) {
      return 'both';
    }
    if (AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.breastLeftCues,
    )) {
      return 'left';
    }
    if (AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.breastRightCues,
    )) {
      return 'right';
    }
    final code = AiNannyIntentLexicon.parseBreastSide(low);
    if (code == 'E') return 'left';
    if (code == 'D') return 'right';
    return null;
  }

  static String? _hhmm(String hour, String? minute) {
    final h = int.tryParse(hour);
    if (h == null || h < 0 || h > 23) return null;
    final m = int.tryParse(minute ?? '0') ?? 0;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static double? _decimalFromMatch(RegExpMatch m) {
    final whole = int.tryParse(m.group(1) ?? '');
    if (whole == null) return null;
    final frac = m.group(2);
    if (frac == null || frac.isEmpty) return whole.toDouble();
    if (frac.length >= 3) return whole + int.parse(frac) / 1000.0;
    return whole + int.parse(frac) / mathPow10(frac.length);
  }

  static double mathPow10(int digits) {
    var p = 1.0;
    for (var i = 0; i < digits; i++) {
      p *= 10;
    }
    return p;
  }
}
