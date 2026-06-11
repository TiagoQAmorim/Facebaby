import '../models/ai/ai_nanny_parsed_message.dart';
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

  /// Duração de sono (até ~10h) — "dormiu por 72 minutos", "1h30", etc.
  static int? parseSleepDurationMinutes(String text) {
    final low = text.toLowerCase();
    var total = 0;
    var found = false;

    final hours = RegExp(r'(\d+)\s*(?:h|horas?|hours?)\b').allMatches(low);
    for (final m in hours) {
      final h = int.tryParse(m.group(1) ?? '');
      if (h != null && h > 0 && h < 24) {
        total += h * 60;
        found = true;
      }
    }

    final mins = RegExp(
      r'(\d+)\s*(?:min(?:utos?)?|minutes?|m)\b',
      caseSensitive: false,
    ).allMatches(low);
    for (final m in mins) {
      final n = int.tryParse(m.group(1) ?? '');
      if (n != null && n > 0 && n < 600) {
        total += n;
        found = true;
      }
    }

    if (!found) {
      final alone = RegExp(
        r'(?:dormiu|soneca|sono|dormindo)\s*(?:por\s*)?(\d{1,3})\s*(?:min)?',
        caseSensitive: false,
      ).firstMatch(low);
      if (alone != null) {
        final n = int.tryParse(alone.group(1) ?? '');
        if (n != null && n > 0 && n < 600) {
          total = n;
          found = true;
        }
      }
    }

    if (found && total > 0) return total;
    final short = parseDurationMinutes(text);
    if (short != null) return short;
    return parseDurationHoursAsMinutes(text);
  }

  /// Início do sono quando se sabe duração e hora de fim (ex.: às 18:03).
  static DateTime? computeSleepStartedAt({
    required int durationMinutes,
    String? endTime24h,
    DateTime? onDay,
  }) {
    final day = onDay ?? DateTime.now();
    late DateTime end;
    if (endTime24h != null && endTime24h.contains(':')) {
      final parts = endTime24h.split(':');
      final h = int.tryParse(parts[0]) ?? 12;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      end = DateTime(day.year, day.month, day.day, h, m);
    } else {
      end = DateTime.now();
    }
    return end.subtract(Duration(minutes: durationMinutes));
  }

  static bool textImpliesCompletedSleep(String text) {
    final low = text.toLowerCase();
    if (AiNannyIntentLexicon.textImpliesWake(low)) return false;
    return AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.sleepCompleteCues,
    );
  }

  static bool textImpliesSleepStartNow(String text) {
    final low = text.toLowerCase();
    if (textImpliesCompletedSleep(text)) return false;
    return low.contains('agora') ||
        low.contains('now') ||
        AiNannyIntentLexicon.containsAny(
          low,
          AiNannyIntentLexicon.sleepStartCues,
        );
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

  /// 1h, 1h12, 1 hora, 1h30 → minutos
  static int? parseDurationHoursAsMinutes(String text) {
    final low = text.toLowerCase().trim();
    if (low.isEmpty) return null;

    var m = RegExp(
      r'(\d{1,2})\s*h\s*(\d{1,2})?\b',
      caseSensitive: false,
    ).firstMatch(low);
    if (m != null) {
      final h = int.tryParse(m.group(1)!);
      if (h == null || h > 24) return null;
      final extra = m.group(2);
      final mins = extra != null ? int.tryParse(extra) ?? 0 : 0;
      final total = h * 60 + mins;
      if (total > 0 && total <= 24 * 60) return total;
    }

    m = RegExp(
      r'(\d{1,2})\s*(?:hora|horas|hr|hours?)\b',
      caseSensitive: false,
    ).firstMatch(low);
    if (m != null) {
      final h = int.tryParse(m.group(1)!);
      if (h != null && h > 0 && h <= 24) return h * 60;
    }

    if (RegExp(r'^\d{1,2}h$').hasMatch(low)) {
      final h = int.tryParse(low.replaceAll('h', ''));
      if (h != null && h > 0) return h * 60;
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
    final isGain = AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.weightGainCues,
    );
    final isLoss = AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.weightLossCues,
    );
    if (!isGain && !isLoss) return null;

    final g = RegExp(
      r'(\d{2,4})\s*(?:g|gramas?|grams?|grammes?|grammi|gramm)\b',
      caseSensitive: false,
    ).firstMatch(low);
    if (g != null) {
      final n = int.tryParse(g.group(1)!);
      if (n == null) return null;
      final sign = _weightDeltaSign(low, isGain: isGain, isLoss: isLoss);
      return sign * n;
    }

    final kg = RegExp(
      r'(\d{1,2})(?:[,.](\d{1,3}))?\s*(?:kg|kilogram|kilograms|quilo|quilos)\b',
      caseSensitive: false,
    ).firstMatch(low);
    if (kg != null) {
      final v = _decimalFromMatch(kg);
      if (v != null && v > 0 && v < 10) {
        final grams = (v * 1000).round();
        final sign = _weightDeltaSign(low, isGain: isGain, isLoss: isLoss);
        return sign * grams;
      }
    }
    return null;
  }

  static int _weightDeltaSign(
    String low, {
    required bool isGain,
    required bool isLoss,
  }) {
    if (isLoss && !isGain) return -1;
    if (isGain && !isLoss) return 1;
    var lossAt = -1;
    for (final cue in AiNannyIntentLexicon.weightLossCues) {
      final i = low.lastIndexOf(cue);
      if (i > lossAt) lossAt = i;
    }
    var gainAt = -1;
    for (final cue in AiNannyIntentLexicon.weightGainCues) {
      final i = low.lastIndexOf(cue);
      if (i > gainAt) gainAt = i;
    }
    return lossAt > gainAt ? -1 : 1;
  }

  /// Cloud às vezes manda `{ value: 200, unit: "g" }` com `mode: total` — vira delta.
  static void normalizeGrowthWeightFields(
    Map<String, dynamic> fields,
    String sourceText,
  ) {
    final wVal = fields['value'];
    if (wVal == null) return;

    final unit = '${fields['unit'] ?? ''}'.toLowerCase();
    final mode = '${fields['mode'] ?? 'total'}';
    if (unit == 'g' || mode == 'delta') {
      fields['mode'] = 'delta';
      fields['unit'] = 'g';
      return;
    }

    final low = sourceText.toLowerCase();
    final hasGainCue = AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.weightGainCues,
    );
    final hasLossCue = AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.weightLossCues,
    );
    if ((!hasGainCue && !hasLossCue) || mode != 'total') return;

    final n = (wVal is num) ? wVal.toDouble() : double.tryParse('$wVal');
    if (n == null) return;

    final mentionsGrams = RegExp(
      r'\d+\s*(?:g|gramas?|grams?)\b',
      caseSensitive: false,
    ).hasMatch(low);
    if (mentionsGrams && n >= 20 && n <= 5000) {
      fields['mode'] = 'delta';
      fields['unit'] = 'g';
    }
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
      r'(\d+(?:[,.]\d+)?)\s*(?:cm|centimetros?|centímetros?|centimeter|centimetre|centimetri)',
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

  /// Data relativa para consulta/vacina: hoje, amanhã, próxima sexta → ISO `YYYY-MM-DD`.
  static String? parseAppointmentDate(String text, {DateTime? now}) {
    final low = text.toLowerCase();
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);

    if (low.contains('hoje') || low.contains('today')) {
      return _isoDate(today);
    }
    if (low.contains('amanh') || low.contains('tomorrow')) {
      return _isoDate(today.add(const Duration(days: 1)));
    }

    final weekday = _weekdayFromText(low);
    if (weekday != null) {
      var diff = weekday - today.weekday;
      if (diff <= 0) diff += 7;
      return _isoDate(today.add(Duration(days: diff)));
    }

    final m = RegExp(r'(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?').firstMatch(low);
    if (m != null) {
      final day = int.tryParse(m.group(1)!);
      final month = int.tryParse(m.group(2)!);
      if (day != null && month != null && day >= 1 && month >= 1 && month <= 12) {
        var year = int.tryParse(m.group(3) ?? '') ?? today.year;
        if (year < 100) year += 2000;
        return _isoDate(DateTime(year, month, day));
      }
    }
    return null;
  }

  /// Nome da vacina a partir da frase (B1, BCG, pentavalente, etc.).
  static String? inferVaccineName(String text) {
    final low = text.toLowerCase();
    if (!low.contains('vacin') && !low.contains('vaccin')) return null;

    const known = <(String, String)>[
      ('bcg', 'BCG'),
      ('pentavalente', 'Pentavalente'),
      ('pentavalent', 'Pentavalente'),
      ('hexavalente', 'Hexavalente'),
      ('hexa', 'Hexavalente'),
      ('pneumocócica', 'Pneumocócica'),
      ('pneumococica', 'Pneumocócica'),
      ('pneumo', 'Pneumocócica'),
      ('rotavírus', 'Rotavírus'),
      ('rotavirus', 'Rotavírus'),
      ('meningocócica', 'Meningocócica'),
      ('meningo', 'Meningocócica'),
      ('gripe', 'Gripe'),
      ('influenza', 'Gripe'),
      ('covid', 'COVID-19'),
      ('tríplice viral', 'Tríplice viral'),
      ('triplice viral', 'Tríplice viral'),
      ('tríplice', 'Tríplice viral'),
      ('triplice', 'Tríplice viral'),
      ('dpt', 'DTP'),
      ('dtp', 'DTP'),
      ('poliomielite', 'Poliomielite'),
      ('polio', 'Poliomielite'),
      ('sarampo', 'Sarampo'),
      ('vip', 'VIP'),
      ('vop', 'VOP'),
      ('mmr', 'MMR'),
      ('hpv', 'HPV'),
    ];
    for (final k in known) {
      if (low.contains(k.$1)) return k.$2;
    }

    final afterVacina = RegExp(
      r'vacina\s+([a-záàâãéêíóôõúç0-9][\wáàâãéêíóôõúç0-9-]*)',
      caseSensitive: false,
    ).firstMatch(low);
    if (afterVacina != null) {
      final raw = afterVacina.group(1)!.trim();
      if (raw.length <= 24) return _titleCaseVaccineToken(raw);
    }

    final code = RegExp(
      r'\b([a-z]\d{1,2})\b',
      caseSensitive: false,
    ).firstMatch(low);
    if (code != null) return code.group(1)!.toUpperCase();

    return null;
  }

  static String _titleCaseVaccineToken(String raw) {
    if (RegExp(r'^[a-z]\d+$', caseSensitive: false).hasMatch(raw)) {
      return raw.toUpperCase();
    }
    if (raw.length <= 4 && raw == raw.toUpperCase()) return raw;
    return raw[0].toUpperCase() + raw.substring(1);
  }

  /// Converte inteiros vindos do JSON cloud (`"25"`, `25.0`, etc.).
  static int? coercePositiveInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value > 0 ? value : null;
    if (value is num) {
      final n = value.toInt();
      return n > 0 ? n : null;
    }
    if (value is String) {
      final n = int.tryParse(value.trim());
      return n != null && n > 0 ? n : null;
    }
    return null;
  }

  /// Dias até a próxima dose: "daqui a 60 dias", "próxima em 30 dias".
  static int? parseVaccineNextDueInDays(String text) {
    final low = text.toLowerCase();
    final hasNextCue = low.contains('proxim') ||
        low.contains('próxim') ||
        low.contains('daqui a') ||
        low.contains('daqui à');
    if (!hasNextCue && !low.contains(' dias')) return null;

    final patterns = <RegExp>[
      RegExp(
        r'(?:proxim\w*|próxim\w*)[^.]{0,50}?(?:daqui\s+a|daqui\s+à|em)\s*(\d{1,3})\s*dias',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:só\s+)?(?:daqui\s+a|daqui\s+à|em)\s*(\d{1,3})\s*dias',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:para\s+)?daqui\s+(?:a\s+|à\s+)?(\d{1,3})\s*dias',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d{1,3})\s*dias\s*(?:para|pra|até|ate)\s*(?:a\s+)?(?:proxim|próxim)',
        caseSensitive: false,
      ),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(low);
      if (m != null) {
        final days = int.tryParse(m.group(1)!);
        if (days != null && days > 0 && days <= 730) return days;
      }
    }
    return null;
  }

  /// Data ISO da próxima dose (hoje + N dias) quando a frase indicar intervalo.
  static String? parseVaccineNextDueDateIso(String text, {DateTime? now}) {
    final days = parseVaccineNextDueInDays(text);
    if (days == null) return null;
    return nextDueIsoFromDays(days, now: now);
  }

  static String nextDueIsoFromDays(int days, {DateTime? now}) {
    final base = now ?? DateTime.now();
    final due =
        DateTime(base.year, base.month, base.day).add(Duration(days: days));
    return '${due.year.toString().padLeft(4, '0')}-'
        '${due.month.toString().padLeft(2, '0')}-'
        '${due.day.toString().padLeft(2, '0')}';
  }

  /// `taken` quando tomou/aplicou hoje; `scheduled` para lembrete/agenda futura.
  static String inferVaccineStatus(String text) {
    final low = text.toLowerCase();
    final futureDays = parseVaccineNextDueInDays(text);
    final futureDue = futureDays != null ||
        RegExp(r'\bdaqui\b', caseSensitive: false).hasMatch(low) ||
        RegExp(r'\bpara\s+daqui\b', caseSensitive: false).hasMatch(low);
    final taken = AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.takenCues,
    );
    final scheduled = AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.scheduleCues,
    );
    final createRecord = (low.contains('criar') || low.contains('crie')) &&
        (low.contains('registro') || low.contains('lembrete'));
    final registerFuture = (low.contains('registr') || low.contains('agend')) &&
        futureDue &&
        !taken;
    if (taken) return 'taken';
    if (scheduled ||
        registerFuture ||
        (futureDue && !taken) ||
        (createRecord && futureDue)) {
      return 'scheduled';
    }
    if (AiNannyIntentLexicon.containsAny(low, AiNannyIntentLexicon.todayCues) ||
        low.contains('aplicad') ||
        low.contains('recebeu')) {
      return 'taken';
    }
    return 'taken';
  }

  /// Motivo padrão quando o utilizador diz "consulta" sem especialidade.
  static String? inferAppointmentReason(String text) {
    final low = text.toLowerCase();
    for (final s in [
      'pediatra',
      'pediatrician',
      'cardiolog',
      'neurolog',
      'ginecolog',
      'oftalmolog',
      'kindesarzt',
    ]) {
      if (low.contains(s)) return s;
    }
    if (low.contains('consulta') ||
        low.contains('appointment') ||
        low.contains('doctor visit') ||
        low.contains('médico') ||
        low.contains('medico')) {
      return 'Consulta';
    }
    return null;
  }

  static int? _weekdayFromText(String low) {
    const map = {
      'segunda': DateTime.monday,
      'monday': DateTime.monday,
      'lunes': DateTime.monday,
      'lundi': DateTime.monday,
      'montag': DateTime.monday,
      'terça': DateTime.tuesday,
      'terca': DateTime.tuesday,
      'tuesday': DateTime.tuesday,
      'martes': DateTime.tuesday,
      'mardi': DateTime.tuesday,
      'dienstag': DateTime.tuesday,
      'quarta': DateTime.wednesday,
      'wednesday': DateTime.wednesday,
      'miércoles': DateTime.wednesday,
      'miercoles': DateTime.wednesday,
      'mercredi': DateTime.wednesday,
      'mittwoch': DateTime.wednesday,
      'quinta': DateTime.thursday,
      'thursday': DateTime.thursday,
      'jueves': DateTime.thursday,
      'jeudi': DateTime.thursday,
      'donnerstag': DateTime.thursday,
      'sexta': DateTime.friday,
      'friday': DateTime.friday,
      'viernes': DateTime.friday,
      'vendredi': DateTime.friday,
      'freitag': DateTime.friday,
      'sábado': DateTime.saturday,
      'sabado': DateTime.saturday,
      'saturday': DateTime.saturday,
      'samstag': DateTime.saturday,
      'domingo': DateTime.sunday,
      'sunday': DateTime.sunday,
      'dimanche': DateTime.sunday,
      'sonntag': DateTime.sunday,
    };
    for (final e in map.entries) {
      if (low.contains(e.key)) return e.value;
    }
    return null;
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Tipos canónicos do schema (cloud/local podem devolver `height`, `growth`, etc.).
  static String canonicalRecordType(
    String type,
    Map<String, dynamic> fields,
  ) {
    var t = type.trim().toLowerCase();
    if (t == 'wake' || t == 'woke' || t == 'awake' || t == 'awakening') {
      return 'sleep';
    }
    if (t == 'height' || t == 'altura') return 'growth_height';
    if (t == 'weight' || t == 'peso') return 'growth_weight';

    if (t == 'growth' || t == 'crescimento' || t == 'measurement') {
      final mt = '${fields['measurementType'] ?? ''}'.toLowerCase();
      if (mt == 'height' || mt == 'altura') return 'growth_height';
      if (mt == 'weight' || mt == 'peso') return 'growth_weight';
      final unit = '${fields['unit'] ?? ''}'.toLowerCase();
      if (unit == 'cm') return 'growth_height';
      if (unit == 'kg' || unit == 'g') return 'growth_weight';
    }
    return t;
  }

  static const knownRecordTypes = {
    'diaper',
    'feeding',
    'sleep',
    'health_symptom',
    'growth_weight',
    'growth_height',
    'vaccine',
    'appointment',
    'memory',
  };

  /// Cloud às vezes devolve só `{ time: now }` sem tipo útil.
  static bool isLowInformationRecord(AiNannyStructuredRecord r) {
    final canonical = canonicalRecordType(r.type, r.fields);
    if (!knownRecordTypes.contains(canonical)) return true;
    final substantive = r.fields.keys.where(
      (k) => k != 'time' && k != 'sleepStatus' && r.fields[k] != null,
    );
    if (substantive.isEmpty && r.missingFields.isEmpty) {
      return canonical != 'sleep';
    }
    return false;
  }

  /// Remove campos obrigatórios de outros tipos (ex.: `pee` num registro de altura).
  static Set<String> sanitizeMissingForType(
    String type,
    Set<String> missing,
  ) {
    final allowed = switch (type) {
      'growth_height' || 'growth_weight' => const {'value'},
      'diaper' => const {'pee', 'poop'},
      'feeding' => const {
        'feedingType',
        'breastSide',
        'durationMinutes',
        'amountMl',
      },
      'sleep' => const {'startedAt', 'sleepStatus', 'durationMinutes'},
      'health_symptom' => const {'symptoms', 'temperatureCelsius'},
      'vaccine' => const {'vaccineName', 'date'},
      'appointment' => const {'reasonOrSpecialty', 'date'},
      _ => const <String>{},
    };
    if (allowed.isEmpty) {
      return missing.where((f) => f != 'type' && f != 'measurementType').toSet();
    }
    return missing.where(allowed.contains).toSet();
  }
}
