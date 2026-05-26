import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../utils/ai_nanny_parse_normalize.dart';
import 'ai_nanny_intent_lexicon.dart';

/// Fallback offline: léxico multilíngue + normalização numérica (apoio ao parser IA).
abstract final class AiNannyLocalMessageParser {
  static AiNannyParseResult parse(
    String message, {
    DateTime? now,
  }) {
    final text = message.trim();
    if (text.isEmpty) {
      return const AiNannyParseResult(classification: 'chat_only');
    }
    final low = text.toLowerCase();
    final records = <AiNannyStructuredRecord>[];

    final diaper = _parseDiaper(low);
    if (diaper != null) records.add(diaper);

    final feeding = _parseFeeding(text, low);
    if (feeding != null) records.add(feeding);

    final symptom = _parseSymptom(text, low);
    if (symptom != null) records.add(symptom);

    for (final w in _parseWeights(text, low)) {
      records.add(w);
    }
    for (final h in _parseHeights(text, low)) {
      records.add(h);
    }

    final vaccine = _parseVaccine(low);
    if (vaccine != null) records.add(vaccine);

    final appointment = _parseAppointment(low);
    if (appointment != null) records.add(appointment);

    if (records.isEmpty) {
      return const AiNannyParseResult(classification: 'chat_only');
    }

    return AiNannyParseResult(
      classification: 'create_records',
      records: records,
      needsConfirmation: true,
    );
  }

  static AiNannyStructuredRecord? _parseDiaper(String low) {
    if (!AiNannyIntentLexicon.hasDiaperCue(low) &&
        !AiNannyIntentLexicon.hasPeeCue(low) &&
        !AiNannyIntentLexicon.hasPooCue(low)) {
      return null;
    }

    final pee = AiNannyIntentLexicon.hasPeeCue(low);
    final poop = AiNannyIntentLexicon.hasPooCue(low);
    if (!pee && !poop) {
      return const AiNannyStructuredRecord(
        type: 'diaper',
        missingFields: ['pee', 'poop'],
        fields: {'pee': false, 'poop': false, 'time': 'now'},
      );
    }

    return AiNannyStructuredRecord(
      type: 'diaper',
      fields: {'pee': pee, 'poop': poop, 'time': 'now'},
    );
  }

  static AiNannyStructuredRecord? _parseFeeding(String text, String low) {
    final ml = AiNannyParseNormalize.parseAmountMl(text);
    final hasFeed =
        AiNannyIntentLexicon.hasFeedingCue(low) || ml != null;
    if (!hasFeed) return null;

    if (ml != null) {
      return AiNannyStructuredRecord(
        type: 'feeding',
        fields: {
          'feedingType': 'bottle',
          'amountMl': ml,
          'time': 'now',
        },
      );
    }

    if (AiNannyIntentLexicon.isBottleSubtype(low)) {
      return AiNannyStructuredRecord(
        type: 'feeding',
        missingFields: ml == null ? ['amountMl'] : [],
        fields: {
          'feedingType': 'bottle',
          'time': 'now',
        },
      );
    }

    if (AiNannyIntentLexicon.containsAny(low, AiNannyIntentLexicon.formulaCues)) {
      return const AiNannyStructuredRecord(
        type: 'feeding',
        fields: {'feedingType': 'formula', 'time': 'now'},
      );
    }

    if (AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.expressedMilkCues,
    )) {
      return const AiNannyStructuredRecord(
        type: 'feeding',
        fields: {'feedingType': 'expressed_milk', 'time': 'now'},
      );
    }

    final side = AiNannyParseNormalize.parseBreastSideCanonical(text);
    final mins = AiNannyParseNormalize.parseDurationMinutes(text);
    final isBreast = side != null ||
        mins != null ||
        AiNannyIntentLexicon.containsAny(
          low,
          AiNannyIntentLexicon.breastLeftCues,
        ) ||
        AiNannyIntentLexicon.containsAny(
          low,
          AiNannyIntentLexicon.breastRightCues,
        ) ||
        AiNannyIntentLexicon.containsAny(
          low,
          AiNannyIntentLexicon.breastBothCues,
        ) ||
        (AiNannyIntentLexicon.hasFeedingCue(low) &&
            !AiNannyIntentLexicon.isBottleSubtype(low) &&
            !AiNannyIntentLexicon.containsAny(
              low,
              AiNannyIntentLexicon.formulaCues,
            ));

    if (isBreast) {
      final missing = <String>[];
      if (side == null) missing.add('breastSide');
      if (mins == null) missing.add('durationMinutes');
      return AiNannyStructuredRecord(
        type: 'feeding',
        missingFields: missing,
        fields: {
          'feedingType': 'breastfeeding',
          if (side != null) 'breastSide': side,
          if (mins != null) 'durationMinutes': mins,
          'time': 'now',
        },
      );
    }

    if (AiNannyIntentLexicon.hasFeedingCue(low)) {
      return const AiNannyStructuredRecord(
        type: 'feeding',
        missingFields: ['feedingType'],
        fields: {'feedingType': 'unknown', 'time': 'now'},
      );
    }

    return null;
  }

  static AiNannyStructuredRecord? _parseSymptom(String text, String low) {
    final temp = AiNannyParseNormalize.parseTemperatureCelsius(text);
    final symptoms = <String>[];
    if (temp != null && temp >= 35) {
      symptoms.add('elevated_temperature');
    }
    if (AiNannyIntentLexicon.containsAny(low, AiNannyIntentLexicon.symptomCues)) {
      if (low.contains('chor') ||
          low.contains('cry') ||
          low.contains('llor') ||
          low.contains('pleur') ||
          low.contains('wein') ||
          low.contains('piant')) {
        symptoms.add('crying');
      }
      if (low.contains('cólic') ||
          low.contains('colic') ||
          low.contains('kolik') ||
          low.contains('colique')) {
        symptoms.add('colic');
      }
      if (low.contains('reflux')) symptoms.add('reflux');
    }

    if (symptoms.isEmpty && temp == null) return null;

    return AiNannyStructuredRecord(
      type: 'health_symptom',
      fields: {
        'symptoms': symptoms,
        if (temp != null) 'temperatureCelsius': temp,
        'time': 'now',
      },
    );
  }

  static List<AiNannyStructuredRecord> _parseWeights(String text, String low) {
    final delta = AiNannyParseNormalize.parseWeightDeltaGrams(text);
    if (delta != null) {
      return [
        AiNannyStructuredRecord(
          type: 'growth_weight',
          fields: {
            'measurementType': 'weight',
            'value': delta,
            'unit': 'g',
            'mode': 'delta',
          },
        ),
      ];
    }

    final kg = AiNannyParseNormalize.parseWeightKgTotal(text);
    if (kg != null) {
      return [
        AiNannyStructuredRecord(
          type: 'growth_weight',
          fields: {
            'measurementType': 'weight',
            'value': kg,
            'unit': 'kg',
            'mode': 'total',
          },
        ),
      ];
    }
    return const [];
  }

  static List<AiNannyStructuredRecord> _parseHeights(String text, String low) {
    final delta = AiNannyParseNormalize.parseHeightDeltaCm(text);
    if (delta != null) {
      return [
        AiNannyStructuredRecord(
          type: 'growth_height',
          fields: {
            'measurementType': 'height',
            'value': delta,
            'unit': 'cm',
            'mode': 'delta',
          },
        ),
      ];
    }

    final cm = AiNannyParseNormalize.parseHeightCmTotal(text);
    if (cm != null && cm >= 30) {
      return [
        AiNannyStructuredRecord(
          type: 'growth_height',
          fields: {
            'measurementType': 'height',
            'value': cm,
            'unit': 'cm',
            'mode': 'total',
          },
        ),
      ];
    }
    return const [];
  }

  static AiNannyStructuredRecord? _parseVaccine(String low) {
    if (!AiNannyIntentLexicon.containsAny(low, AiNannyIntentLexicon.vaccineCues)) {
      return null;
    }

    final scheduled =
        AiNannyIntentLexicon.containsAny(low, AiNannyIntentLexicon.scheduleCues);
    final taken =
        AiNannyIntentLexicon.containsAny(low, AiNannyIntentLexicon.takenCues);

    String? name;
    if (low.contains('bcg')) name = 'BCG';
    if (low.contains('pentavalent')) name = 'pentavalente';

    final missing = <String>[];
    if (name == null || name.isEmpty) missing.add('vaccineName');
    if (scheduled && !_hasDateHint(low)) missing.add('date');

    return AiNannyStructuredRecord(
      type: 'vaccine',
      missingFields: missing,
      fields: {
        'status': scheduled && !taken ? 'scheduled' : 'taken',
        if (name != null) 'vaccineName': name,
        ..._dateFields(low),
        if (AiNannyParseNormalize.parseTime24h(low) != null)
          'time': AiNannyParseNormalize.parseTime24h(low),
      },
    );
  }

  static AiNannyStructuredRecord? _parseAppointment(String low) {
    if (!AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.consultationCues,
    )) {
      return null;
    }

    String? specialty;
    for (final s in [
      'pediatra',
      'pediatrician',
      'cardiolog',
      'neurolog',
      'ginecolog',
      'oftalmolog',
      'kindesarzt',
    ]) {
      if (low.contains(s)) {
        specialty = s;
        break;
      }
    }

    final missing = <String>[];
    if (specialty == null) missing.add('reasonOrSpecialty');
    if (!_hasDateHint(low)) missing.add('date');
    if (AiNannyParseNormalize.parseTime24h(low) == null) {
      missing.add('time');
    }

    return AiNannyStructuredRecord(
      type: 'appointment',
      missingFields: missing,
      fields: {
        if (specialty != null) 'reasonOrSpecialty': specialty,
        ..._dateFields(low),
        if (AiNannyParseNormalize.parseTime24h(low) != null)
          'time': AiNannyParseNormalize.parseTime24h(low),
      },
    );
  }

  static Map<String, dynamic> _dateFields(String low) {
    if (AiNannyIntentLexicon.containsAny(low, AiNannyIntentLexicon.todayCues)) {
      return {'date': 'today'};
    }
    if (AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.tomorrowCues,
    )) {
      return {'date': 'tomorrow'};
    }
    if (low.contains('segunda') ||
        low.contains('monday') ||
        low.contains('lunes') ||
        low.contains('lundi') ||
        low.contains('montag')) {
      return {'date': 'next_monday'};
    }
    return {};
  }

  static bool _hasDateHint(String low) =>
      _dateFields(low).isNotEmpty ||
      RegExp(r'day\s+\d{1,2}|dia\s+\d{1,2}').hasMatch(low);
}
