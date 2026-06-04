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

    final vaccine = _parseVaccine(text);
    if (vaccine != null) records.add(vaccine);

    final appointment = _parseAppointment(text);
    if (appointment != null) records.add(appointment);

    final sleep = _parseSleep(text);
    if (sleep != null) records.add(sleep);

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
    final hasFeverCue = AiNannyIntentLexicon.hasTemperatureCue(low);
    if (hasFeverCue && temp == null) {
      return AiNannyStructuredRecord(
        type: 'health_symptom',
        missingFields: ['temperatureCelsius'],
        fields: {
          'symptoms': ['fever'],
          'feverReported': true,
          'time': 'now',
        },
      );
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

  static AiNannyStructuredRecord? _parseVaccine(String text) {
    final low = text.toLowerCase();
    if (!AiNannyIntentLexicon.containsAny(low, AiNannyIntentLexicon.vaccineCues)) {
      return null;
    }

    final name = AiNannyParseNormalize.inferVaccineName(text);
    final status = AiNannyParseNormalize.inferVaccineStatus(text);
    final dateIso = AiNannyParseNormalize.parseAppointmentDate(text);
    final time = AiNannyParseNormalize.parseTime24h(text);
    final nextDays = AiNannyParseNormalize.parseVaccineNextDueInDays(text);
    final nextDueIso = AiNannyParseNormalize.parseVaccineNextDueDateIso(text);

    final missing = <String>[];
    if (name == null || name.isEmpty) missing.add('vaccineName');
    if (status == 'scheduled' &&
        dateIso == null &&
        nextDueIso == null &&
        nextDays == null) {
      missing.add('date');
    }

    return AiNannyStructuredRecord(
      type: 'vaccine',
      missingFields: missing,
      fields: {
        'status': status,
        if (name != null) 'vaccineName': name,
        if (dateIso != null) 'date': dateIso,
        if (time != null) 'time': time,
        if (nextDays != null) 'nextDueInDays': nextDays,
        if (nextDueIso != null) 'nextDueDate': nextDueIso,
      },
    );
  }

  static AiNannyStructuredRecord? _parseAppointment(String text) {
    final low = text.toLowerCase();
    final hasConsult = AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.consultationCues,
    );
    final hasSchedule = AiNannyIntentLexicon.containsAny(
      low,
      AiNannyIntentLexicon.scheduleCues,
    );
    if (!hasConsult && !hasSchedule) return null;
    if (hasSchedule && !hasConsult && !low.contains('médic') && !low.contains('medico')) {
      return null;
    }

    final specialty = AiNannyParseNormalize.inferAppointmentReason(text);
    final dateIso = AiNannyParseNormalize.parseAppointmentDate(text);
    final time = AiNannyParseNormalize.parseTime24h(text);

    final missing = <String>[];
    if (specialty == null) missing.add('reasonOrSpecialty');
    if (dateIso == null) missing.add('date');

    return AiNannyStructuredRecord(
      type: 'appointment',
      missingFields: missing,
      fields: {
        if (specialty != null) 'reasonOrSpecialty': specialty,
        if (dateIso != null) 'date': dateIso,
        if (time != null) 'time': time,
      },
    );
  }

  static bool _hasDateHint(String low) =>
      AiNannyParseNormalize.parseAppointmentDate(low) != null ||
      RegExp(r'day\s+\d{1,2}|dia\s+\d{1,2}').hasMatch(low);

  static AiNannyStructuredRecord? _parseSleep(String text) {
    final low = text.toLowerCase();
    if (!AiNannyIntentLexicon.hasSleepCue(low)) return null;

    // "acordou e mamou" = contexto duplo; "acordou com fome" ainda é fim de sono.
    if (AiNannyIntentLexicon.textImpliesWake(low) &&
        (AiNannyIntentLexicon.hasExplicitFeedingIntent(low) ||
            AiNannyIntentLexicon.hasTemperatureCue(low) ||
            AiNannyIntentLexicon.hasDiaperCue(low))) {
      return null;
    }

    final waking = AiNannyIntentLexicon.textImpliesWake(low);
    final mins = AiNannyParseNormalize.parseSleepDurationMinutes(text);
    final time = AiNannyParseNormalize.parseTime24h(text);

    if (waking) {
      final missing = <String>[];
      if (mins == null) missing.add('durationMinutes');
      return AiNannyStructuredRecord(
        type: 'sleep',
        missingFields: missing,
        fields: {
          'action': 'end',
          'sleepStatus': 'woke',
          if (mins != null) 'durationMinutes': mins,
          'time': time ?? 'now',
        },
      );
    }

    if (mins != null && mins > 0) {
      final started = AiNannyParseNormalize.computeSleepStartedAt(
        durationMinutes: mins,
        endTime24h: time,
      );
      return AiNannyStructuredRecord(
        type: 'sleep',
        fields: {
          'action': 'complete',
          'durationMinutes': mins,
          'sleepStatus': 'slept',
          if (started != null) 'startedAt': started.toIso8601String(),
          if (time != null) 'time': time,
        },
      );
    }

    if (AiNannyParseNormalize.textImpliesSleepStartNow(text)) {
      return AiNannyStructuredRecord(
        type: 'sleep',
        fields: {
          'action': 'start',
          'sleepStatus': 'now',
          'startedAt': DateTime.now().toIso8601String(),
          'time': 'now',
        },
      );
    }

    final missing = <String>['sleepStatus', 'startedAt'];
    return AiNannyStructuredRecord(
      type: 'sleep',
      missingFields: missing,
      fields: {
        'action': 'start',
        'time': time ?? 'now',
      },
    );
  }
}
