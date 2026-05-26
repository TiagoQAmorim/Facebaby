import '../../models/ai/voice_record_interpretation.dart';

import '../../utils/voice_growth_infer.dart' show enhanceVoiceGrowthInterpretation;

import '../../utils/voice_health_infer.dart';

import '../../utils/voice_record_clarification.dart';

import '../../utils/voice_record_infer.dart';

import '../../utils/voice_routine_multi_infer.dart';

import '../../utils/voice_sleep_infer.dart';

import 'ai_nanny_intent_lexicon.dart';



/// Intenção de registro detectada em linguagem natural (IA Babá).

enum AiRegisterIntent {

  unknown,

  diaperPee,

  diaperPoop,

  diaperBoth,

  diaperUnspecified,

  feeding,

  sleepStart,

  sleepEnd,

  sleepComplete,

  weight,

  height,

  temperature,

  medicine,

  bath,

  memory,

  consultation,

  vaccine,

}



/// Resultado do parser local — base para salvar no app.

class AiNannyParsedIntent {

  const AiNannyParsedIntent({

    required this.intent,

    this.confidence = 0,

    this.interpretation,

    this.missingFields = const [],

  });



  final AiRegisterIntent intent;

  final double confidence;

  final VoiceRecordInterpretation? interpretation;

  final List<String> missingFields;



  bool get isActionable =>

      intent != AiRegisterIntent.unknown &&

      interpretation != null &&

      interpretation!.canRegister;

}



/// Parser de intenções registráveis (PT-BR, ES, EN, IT, FR, DE).

abstract final class AiNannyIntentParser {

  static AiNannyParsedIntent? parse(String transcript) {

    final text = transcript.trim();

    if (text.isEmpty) {

      return const AiNannyParsedIntent(intent: AiRegisterIntent.unknown);

    }

    final low = text.toLowerCase();



    if (AiNannyIntentLexicon.isGreetingOnly(low)) {

      return const AiNannyParsedIntent(intent: AiRegisterIntent.unknown);

    }



    final wantFeed = transcriptHasFeedingCue(low);

    final wantDiaper = transcriptHasDiaperCue(low) || AiNannyIntentLexicon.hasPeeCue(low);

    if (wantFeed && wantDiaper) {

      return AiNannyParsedIntent(

        intent: AiRegisterIntent.feeding,

        confidence: 0.85,

        interpretation: _mergeMulti(text, low),

      );

    }



    final sleep = _parseSleep(text, low);

    if (sleep != null) return sleep;



    final diaper = _parseDiaper(text, low);

    if (diaper != null) return diaper;



    final feeding = _parseFeeding(text, low);

    if (feeding != null) return feeding;



    final growth = _parseGrowth(text, low);

    if (growth != null) return growth;



    final temp = _parseTemperature(text, low);

    if (temp != null) return temp;



    final medicine = _parseMedicine(text, low);

    if (medicine != null) return medicine;



    final bath = _parseBath(text, low);

    if (bath != null) return bath;



    final memory = _parseMemory(text, low);

    if (memory != null) return memory;



    final health = _parseHealth(text, low);

    if (health != null) return health;



    return const AiNannyParsedIntent(intent: AiRegisterIntent.unknown);

  }



  static VoiceRecordInterpretation interpretLocally(String transcript) {

    final parsed = parse(transcript);

    if (parsed != null &&

        parsed.interpretation != null &&

        parsed.confidence >= 0.65) {

      return enhanceVoiceRecordInterpretation(

        interpretation: parsed.interpretation!,

        transcript: transcript,

      );

    }

    var interp = const VoiceRecordInterpretation.unknown();

    interp = enhanceVoiceGrowthInterpretation(

      interpretation: interp,

      transcript: transcript,

    );

    interp = enhanceVoiceSleepInterpretation(

      interpretation: interp,

      transcript: transcript,

    );

    interp = enhanceVoiceHealthInterpretation(

      interpretation: interp,

      transcript: transcript,

    );

    return enhanceVoiceRecordInterpretation(

      interpretation: interp,

      transcript: transcript,

    );

  }



  static bool transcriptHasRegisterCue(String transcript) {

    final p = parse(transcript);

    return (p?.confidence ?? 0) >= 0.65;

  }



  static VoiceRecordInterpretation _mergeMulti(String text, String low) {

    final events = expandRoutineInterpretations(

      primary: const VoiceRecordInterpretation.unknown(),

      transcript: text,

    );

    return events.isNotEmpty

        ? events.first

        : const VoiceRecordInterpretation(

            type: 'feeding',

            summary: 'Mamada e fralda',

          );

  }



  static AiNannyParsedIntent? _parseSleep(String text, String low) {

    if (!AiNannyIntentLexicon.hasSleepCue(low)) return null;



    final enhanced = enhanceVoiceSleepInterpretation(

      interpretation: const VoiceRecordInterpretation.unknown(),

      transcript: text,

    );

    if (enhanced.type != 'sleep') return null;



    final action = (enhanced.sleep?.action ?? 'complete').toLowerCase();

    final intent = switch (action) {

      'start' => AiRegisterIntent.sleepStart,

      'end' => AiRegisterIntent.sleepEnd,

      _ => AiRegisterIntent.sleepComplete,

    };

    return AiNannyParsedIntent(

      intent: intent,

      confidence: 0.9,

      interpretation: enhanced,

    );

  }



  static AiNannyParsedIntent? _parseDiaper(String text, String low) {

    if (!transcriptHasDiaperCue(low)) {
      return null;
    }



    final kind = resolveDiaperKindFromTranscript(null, text);

    final intent = switch (kind) {

      'pee' => AiRegisterIntent.diaperPee,

      'poo' => AiRegisterIntent.diaperPoop,

      'both' => AiRegisterIntent.diaperBoth,

      _ => AiRegisterIntent.diaperUnspecified,

    };



    final missing = <String>[];

    if (kind == null) missing.add('diaper_kind');

    if (diaperNeedsChangeConfirmation(text)) {

      missing.add('diaper_change_confirm');

    }



    final interp = VoiceRecordInterpretation(

      type: 'diaper',

      summary: _diaperSummary(kind),

      diaper: VoiceDiaperPayload(

        kind: kind,

        changedAt: DateTime.now(),

      ),

    );



    return AiNannyParsedIntent(

      intent: intent,

      confidence: kind != null ? 0.92 : 0.75,

      interpretation: interp,

      missingFields: missing,

    );

  }



  static AiNannyParsedIntent? _parseFeeding(String text, String low) {

    if (!transcriptHasFeedingCue(low)) return null;



    final events = expandRoutineInterpretations(

      primary: const VoiceRecordInterpretation.unknown(),

      transcript: text,

    );

    final feeding = events.where((e) => e.type == 'feeding').firstOrNull;

    final interp = feeding ??

        VoiceRecordInterpretation(

          type: 'feeding',

          summary: 'Mamada',

          feeding: VoiceFeedingPayload(

            subtype: AiNannyIntentLexicon.isBottleSubtype(low)

                ? 'mamadeira'

                : 'peito',

            eventTime: DateTime.now(),

          ),

        );



    final missing = <String>[];

    if (routineRecordNeedsClarification(interp, text)) {

      if ((interp.feeding?.subtype ?? '') == 'peito' &&

          parseBreastSideFromTranscript(interp.feeding?.side, low) == null) {

        missing.add('breast_side');

      }

    }



    return AiNannyParsedIntent(

      intent: AiRegisterIntent.feeding,

      confidence: 0.9,

      interpretation: interp,

      missingFields: missing,

    );

  }



  static AiNannyParsedIntent? _parseGrowth(String text, String low) {

    final enhanced = enhanceVoiceGrowthInterpretation(

      interpretation: const VoiceRecordInterpretation.unknown(),

      transcript: text,

    );

    if (enhanced.type == 'weight') {

      final missing =

          enhanced.weight?.weightKg == null ? ['weight_kg'] : <String>[];

      return AiNannyParsedIntent(

        intent: AiRegisterIntent.weight,

        confidence: enhanced.weight?.weightKg != null ? 0.95 : 0.7,

        interpretation: enhanced,

        missingFields: missing,

      );

    }

    if (enhanced.type == 'height') {

      final hasVal = enhanced.height?.heightCm != null ||

          enhanced.height?.heightDeltaCm != null;

      return AiNannyParsedIntent(

        intent: AiRegisterIntent.height,

        confidence: hasVal ? 0.95 : 0.7,

        interpretation: enhanced,

        missingFields: hasVal ? [] : ['height_cm'],

      );

    }

    return null;

  }



  static AiNannyParsedIntent? _parseTemperature(String text, String low) {

    if (!AiNannyIntentLexicon.hasTemperatureCue(low) &&

        !low.contains('°c') &&

        !low.contains('graus') &&

        !low.contains('degrees')) {

      return null;

    }

    final symptom = symptomInterpretationFromTranscript(text);

    if (symptom == null) return null;

    final missing = symptom.needsHealthFormFields ? ['temperature'] : <String>[];

    return AiNannyParsedIntent(

      intent: AiRegisterIntent.temperature,

      confidence: symptom.symptom?.tempCelsius != null ? 0.93 : 0.8,

      interpretation: symptom,

      missingFields: missing,

    );

  }



  static AiNannyParsedIntent? _parseMedicine(String text, String low) {

    if (!AiNannyIntentLexicon.hasMedicineCue(low)) return null;



    return AiNannyParsedIntent(

      intent: AiRegisterIntent.medicine,

      confidence: 0.88,

      interpretation: VoiceRecordInterpretation(

        type: 'symptom',

        summary: 'Medicamento',

        symptom: VoiceSymptomPayload(

          otherNote: text.trim(),

          occurredAt: DateTime.now(),

        ),

      ),

      missingFields: const [],

    );

  }



  static AiNannyParsedIntent? _parseBath(String text, String low) {

    if (!AiNannyIntentLexicon.hasBathCue(low)) return null;

    return AiNannyParsedIntent(

      intent: AiRegisterIntent.bath,

      confidence: 0.8,

      interpretation: VoiceRecordInterpretation(

        type: 'question',

        summary: 'Banho — registrar em Memórias',

      ),

      missingFields: const ['memory_manual'],

    );

  }



  static AiNannyParsedIntent? _parseMemory(String text, String low) {

    if (!AiNannyIntentLexicon.hasMemoryCue(low)) return null;

    return AiNannyParsedIntent(

      intent: AiRegisterIntent.memory,

      confidence: 0.75,

      interpretation: VoiceRecordInterpretation(

        type: 'question',

        summary: 'Memória / marco',

      ),

      missingFields: const ['memory_manual'],

    );

  }



  static AiNannyParsedIntent? _parseHealth(String text, String low) {

    final enhanced = enhanceVoiceHealthInterpretation(

      interpretation: const VoiceRecordInterpretation.unknown(),

      transcript: text,

    );

    if (!enhanced.canRegister || enhanced.isHealthRegister == false) {

      if (enhanced.type != 'consultation' && enhanced.type != 'vaccine') {

        return null;

      }

    }

    if (enhanced.type == 'consultation') {

      return AiNannyParsedIntent(

        intent: AiRegisterIntent.consultation,

        confidence: 0.85,

        interpretation: enhanced,

        missingFields:

            enhanced.needsHealthFormFields ? ['consultation_title'] : [],

      );

    }

    if (enhanced.type == 'vaccine') {

      return AiNannyParsedIntent(

        intent: AiRegisterIntent.vaccine,

        confidence: 0.85,

        interpretation: enhanced,

        missingFields: enhanced.needsHealthFormFields ? ['vaccine_name'] : [],

      );

    }

    return null;

  }



  static String _diaperSummary(String? kind) => switch (kind) {

        'pee' => 'Fralda com xixi',

        'poo' => 'Fralda com cocô',

        'both' => 'Fralda com xixi e cocô',

        _ => 'Troca de fralda',

      };

}

