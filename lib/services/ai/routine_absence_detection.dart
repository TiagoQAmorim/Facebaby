import '../../utils/ai_nanny_parse_normalize.dart';
import 'ai_nanny_intent_lexicon.dart';

/// Detecta frases de ausência/negação — conversa, sem registro automático.
abstract final class RoutineAbsenceDetection {
  RoutineAbsenceDetection._();

  static Set<String> blockedRecordTypes(String transcript) {
    final blocked = <String>{};
    if (AiNannyIntentLexicon.isDiaperAbsenceObservation(transcript)) {
      blocked.add('diaper');
    }
    if (AiNannyIntentLexicon.isFeedingAbsenceObservation(transcript)) {
      blocked.add('feeding');
    }
    if (isGrowthWeightAbsence(transcript)) blocked.add('growth_weight');
    if (isGrowthHeightAbsence(transcript)) blocked.add('growth_height');
    if (isSleepAbsence(transcript)) blocked.add('sleep');
    return blocked;
  }

  static bool shouldBlock(String transcript, String recordType) =>
      blockedRecordTypes(transcript).contains(recordType);

  static bool isGrowthWeightAbsence(String transcript) {
    if (AiNannyParseNormalize.parseWeightDeltaGrams(transcript) != null) {
      return false;
    }
    final low = transcript.toLowerCase();
    final kgTotal = AiNannyParseNormalize.parseWeightKgTotal(transcript);
    if (kgTotal != null && !AiNannyIntentLexicon.isWeightGainNegated(low)) {
      return false;
    }
    final mentions = AiNannyIntentLexicon.containsAny(
          low,
          AiNannyIntentLexicon.weightCues,
        ) ||
        AiNannyIntentLexicon.containsAny(
          low,
          AiNannyIntentLexicon.weightGainCues,
        ) ||
        AiNannyIntentLexicon.containsAny(
          low,
          AiNannyIntentLexicon.weightLossCues,
        ) ||
        RegExp(r'\bpeso\b').hasMatch(low);
    if (!mentions) return false;
    return AiNannyIntentLexicon.isWeightGainNegated(low);
  }

  static bool isGrowthHeightAbsence(String transcript) {
    if (AiNannyParseNormalize.parseHeightDeltaCm(transcript) != null) {
      return false;
    }
    final low = transcript.toLowerCase();
    final cmTotal = AiNannyParseNormalize.parseHeightCmTotal(transcript);
    if (cmTotal != null &&
        cmTotal >= 30 &&
        !AiNannyIntentLexicon.isHeightGainNegated(low)) {
      return false;
    }
    final mentions = AiNannyIntentLexicon.containsAny(
          low,
          AiNannyIntentLexicon.heightCues,
        ) ||
        AiNannyIntentLexicon.containsAny(
          low,
          AiNannyIntentLexicon.heightGainCues,
        );
    if (!mentions) return false;
    return AiNannyIntentLexicon.isHeightGainNegated(low);
  }

  static bool isSleepAbsence(String transcript) {
    final low = transcript.toLowerCase();
    if (!AiNannyIntentLexicon.hasSleepCue(low)) return false;
    if (AiNannyIntentLexicon.textImpliesWake(low)) return false;
    if (AiNannyParseNormalize.parseSleepDurationMinutes(transcript) != null &&
        !AiNannyIntentLexicon.isSleepNegated(low)) {
      return false;
    }
    return AiNannyIntentLexicon.isSleepNegated(low);
  }
}
