import '../models/ai/voice_record_interpretation.dart';

/// Reforça interpretação de peso/altura quando a IA retorna unknown ou dados incompletos.
VoiceRecordInterpretation enhanceVoiceGrowthInterpretation({
  required VoiceRecordInterpretation interpretation,
  required String transcript,
}) {
  final t = transcript.trim().toLowerCase();
  if (t.isEmpty) return interpretation;

  if (interpretation.type == 'weight') {
    if (_looksLikeFeverNotWeight(t)) return interpretation;
    return _fillWeight(interpretation, t);
  }
  if (interpretation.type == 'height') {
    return _fillHeight(interpretation, t);
  }

  final height = _parseHeight(t);
  if (height != null) {
    return VoiceRecordInterpretation(
      type: 'height',
      summary: _goodHeightSummary(interpretation.summary, height),
      height: height,
    );
  }

  if (_looksLikeFeverNotWeight(t)) {
    return interpretation;
  }

  final weight = _parseWeight(t);
  if (weight != null) {
    return VoiceRecordInterpretation(
      type: 'weight',
      summary: _goodWeightSummary(interpretation.summary, weight),
      weight: weight,
    );
  }

  return interpretation;
}

VoiceRecordInterpretation _fillWeight(
  VoiceRecordInterpretation i,
  String t,
) {
  final w = i.weight;
  if (w?.weightKg != null && w!.weightKg! > 0) return i;
  final parsed = _parseWeight(t);
  if (parsed == null) return i;
  return VoiceRecordInterpretation(
    type: 'weight',
    summary: _goodWeightSummary(i.summary, parsed),
    weight: parsed,
  );
}

VoiceRecordInterpretation _fillHeight(
  VoiceRecordInterpretation i,
  String t,
) {
  final h = i.height;
  if (h?.heightCm != null && h!.heightCm! > 0) return i;
  if (h?.heightDeltaCm != null && h!.heightDeltaCm! > 0) return i;
  final parsed = _parseHeight(t);
  if (parsed == null) return i;
  return VoiceRecordInterpretation(
    type: 'height',
    summary: _goodHeightSummary(i.summary, parsed),
    height: parsed,
  );
}

String _goodWeightSummary(String raw, VoiceWeightPayload w) {
  final s = _weightSummary(w);
  if (s.isEmpty) return raw;
  if (raw.trim().isEmpty || _isBadSummary(raw)) return s;
  return raw;
}

String _goodHeightSummary(String raw, VoiceHeightPayload h) {
  final s = _heightSummary(h);
  if (s.isEmpty) return raw;
  if (raw.trim().isEmpty || _isBadSummary(raw)) return s;
  return raw;
}

bool _isBadSummary(String raw) {
  final l = raw.toLowerCase();
  return l.contains('não identificado') ||
      l.contains('nao identificado') ||
      l.contains('não reconhecido') ||
      l.contains('ambíguo');
}

VoiceHeightPayload? _parseHeight(String t) {
  final absolute = _firstCmAbsolute(t);
  if (absolute != null) {
    return VoiceHeightPayload(heightCm: absolute);
  }

  final delta = _firstCmDelta(t);
  if (delta != null) {
    return VoiceHeightPayload(heightDeltaCm: delta);
  }

  return null;
}

double? _firstCmAbsolute(String t) {
  final patterns = [
    RegExp(r'altura\s*(?:de|é|e)?\s*(\d{2,3})(?:[,.](\d))?\s*(?:cm|cent[ií]metros?)'),
    RegExp(r'(\d{2,3})(?:[,.](\d))?\s*(?:cm|cent[ií]metros?)\s*(?:de\s*altura)?'),
    RegExp(r'mede\s*(\d{2,3})(?:[,.](\d))?\s*(?:cm|cent[ií]metros?)'),
  ];
  for (final re in patterns) {
    final m = re.firstMatch(t);
    if (m != null) {
      final v = _cmFromMatch(m);
      if (v != null && v >= 30 && v <= 220) return v;
    }
  }
  return null;
}

double? _firstCmDelta(String t) {
  if (!t.contains('cresceu') &&
      !t.contains('crescimento') &&
      !t.contains('cresce') &&
      !t.contains('aumentou') &&
      !t.contains('ganhou')) {
    return null;
  }
  var re = RegExp(r'(\d+(?:[,.]\d+)?)\s*(?:cm|cent[ií]metros?)');
  var m = re.firstMatch(t);
  if (m == null) {
    re = RegExp(r'cresceu\s*(\d+(?:[,.]\d+)?)');
    m = re.firstMatch(t);
  }
  if (m == null) return null;
  final v = double.tryParse(m.group(1)!.replaceAll(',', '.'));
  if (v == null || v <= 0 || v > 30) return null;
  return v;
}

double? _cmFromMatch(RegExpMatch m) {
  final whole = int.tryParse(m.group(1) ?? '');
  if (whole == null) return null;
  final frac = m.group(2);
  if (frac == null || frac.isEmpty) return whole.toDouble();
  return whole + int.parse(frac) / 10.0;
}

VoiceWeightPayload? _parseWeight(String t) {
  if (!t.contains('peso') &&
      !t.contains('pesou') &&
      !t.contains('quilo') &&
      !t.contains(' kg') &&
      !t.contains('grama')) {
    return null;
  }

  final g = RegExp(r'(\d{3,5})\s*g(?:ramas?)?').firstMatch(t);
  if (g != null) {
    final grams = int.tryParse(g.group(1)!);
    if (grams != null && grams > 0) {
      return VoiceWeightPayload(weightKg: grams / 1000.0);
    }
  }

  final kg = RegExp(
    r'(\d{1,2})(?:[,.](\d{1,3}))?\s*(?:kg|quilos?|kilos?)',
  ).firstMatch(t);
  if (kg != null) {
    final whole = int.tryParse(kg.group(1)!);
    if (whole == null) return null;
    final frac = kg.group(2);
    var value = whole.toDouble();
    if (frac != null && frac.isNotEmpty) {
      if (frac.length == 3) {
        value = whole + int.parse(frac) / 1000.0;
      } else {
        value = whole + int.parse(frac) / mathPow10(frac.length);
      }
    }
    if (value > 0 && value <= 80) {
      return VoiceWeightPayload(weightKg: value);
    }
  }

  final pesou = RegExp(r'pesou\s*(\d{1,2})(?:[,.](\d{1,3}))?').firstMatch(t);
  if (pesou != null) {
    final whole = int.tryParse(pesou.group(1)!);
    if (whole == null) return null;
    final frac = pesou.group(2);
    var value = whole.toDouble();
    if (frac != null && frac.isNotEmpty) {
      value = whole + int.parse(frac) / (frac.length >= 3 ? 1000 : 10);
    }
    if (value > 0 && value <= 80) {
      return VoiceWeightPayload(weightKg: value);
    }
  }

  return null;
}

double mathPow10(int digits) {
  var p = 1.0;
  for (var i = 0; i < digits; i++) {
    p *= 10;
  }
  return p;
}

String _weightSummary(VoiceWeightPayload w) {
  final kg = w.weightKg;
  if (kg == null) return '';
  final txt = kg == kg.roundToDouble()
      ? '${kg.toInt()} kg'
      : '${kg.toStringAsFixed(2).replaceAll('.', ',')} kg';
  return 'Peso de $txt';
}

bool _looksLikeFeverNotWeight(String t) {
  return t.contains('febre') ||
      t.contains('temperatura') ||
      (t.contains('graus') &&
          (t.contains('febre') || t.contains('temperatura')));
}

String _heightSummary(VoiceHeightPayload h) {
  if (h.heightCm != null) {
    final cm = h.heightCm!;
    final txt = cm == cm.roundToDouble()
        ? '${cm.toInt()} cm'
        : '${cm.toStringAsFixed(1).replaceAll('.', ',')} cm';
    return 'Altura de $txt';
  }
  if (h.heightDeltaCm != null) {
    return 'Altura +${h.heightDeltaCm!.toStringAsFixed(0).replaceAll('.', ',')} cm (soma à última medição)';
  }
  return '';
}
