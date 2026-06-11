import 'package:flutter/foundation.dart';

import '../../models/ai/voice_record_interpretation.dart';
import '../../utils/voice_intent.dart';
import '../../utils/voice_record_infer.dart';
import '../../utils/voice_record_clarification.dart';
import '../../utils/voice_health_infer.dart';
import '../../utils/voice_routine_multi_infer.dart';
import 'ai_nanny_intent_lexicon.dart';
import 'ai_nanny_intent_parser.dart';
import 'routine_absence_detection.dart';
import 'voice_record_api_service.dart';
import '../../i18n/app_i18n.dart';
/// Interpretação de rotina (sono, peso, fralda, etc.) a partir de texto ou voz.
class RoutineRecordInterpreter {
  RoutineRecordInterpreter({VoiceRecordApiService? api})
      : _api = api ?? VoiceRecordApiService();

  final VoiceRecordApiService _api;

  Future<VoiceRecordInterpretation> interpret({
    required String transcript,
    AppLang locale = AppLang.pt,
    String? babyName,
    VoiceRecordInterpretation? hint,
  }) async {
    final text = transcript.trim();
    if (text.isEmpty) {
      return const VoiceRecordInterpretation.unknown();
    }
    if (RoutineAbsenceDetection.isAbsenceOnlyConversation(text)) {
      return const VoiceRecordInterpretation.unknown();
    }

    var interp = AiNannyIntentParser.interpretLocally(text);
    if (hint != null) {
      interp = enhanceVoiceRecordInterpretation(
        interpretation: hint,
        transcript: text,
      );
    }

    if (_needsCloudInterpret(interp, text, hint: hint, transcript: text)) {
      try {
        final remote = await _api.processText(
          transcript: text,
          babyName: babyName,
          locale: locale,
        );
        interp = enhanceVoiceRecordInterpretation(
          interpretation: remote.interpretation,
          transcript: text,
        );
      } catch (e, st) {
        debugPrint('RoutineRecordInterpreter: processText $e\n$st');
      }
    }

    return interp;
  }

  bool _needsCloudInterpret(
    VoiceRecordInterpretation local,
    String text, {
    VoiceRecordInterpretation? hint,
    required String transcript,
  }) {
    if (hint != null &&
        hint.type != 'unknown' &&
        hint.canRegister &&
        local.type == hint.type) {
      return false;
    }
    if (RoutineAbsenceDetection.isAbsenceOnlyConversation(transcript)) {
      return false;
    }
    if (_localInterpretSufficient(local, transcript)) return false;
    final low = text.toLowerCase();
    if (low.contains('registr')) return true;
    return _hasRoutineCue(low);
  }

  /// Evita `processTextRecord` (GPT extra) quando o app já entende a frase.
  bool _localInterpretSufficient(
    VoiceRecordInterpretation local,
    String transcript,
  ) {
    final t = transcript.trim();
    if (t.isEmpty) return false;

    if (symptomInterpretationFromTranscript(t) != null) return true;

    final expanded = expandRoutineInterpretations(
      primary: local,
      transcript: t,
    );
    if (expanded.isNotEmpty) return true;

    if (local.canRegister &&
        local.type != 'unknown' &&
        local.type != 'question') {
      return true;
    }

    return false;
  }

  /// Frase pode exigir interpretação de rotina (evita GPT extra quando é só conversa).
  static bool transcriptHasRoutineCue(String transcript) {
    final low = transcript.trim().toLowerCase();
    if (low.isEmpty) return false;
    if (_RoutineCues.matches(low)) return true;
    return AiNannyIntentParser.transcriptHasRegisterCue(transcript);
  }

  bool _hasRoutineCue(String low) => _RoutineCues.matches(low);
}

abstract final class _RoutineCues {
  static bool matches(String low) =>
      AiNannyIntentLexicon.containsAny(low, AiNannyIntentLexicon.allRoutineCues);
}

/// Quando aplicar registro automaticamente (sem prévia manual).
abstract final class RoutineRecordMatcher {
  RoutineRecordMatcher._();

  static bool shouldAutoApply(
    VoiceRecordInterpretation interp,
    String transcript,
  ) {
    if (!interp.canRegister) return false;
    if (interp.type == 'question') return false;

    final t = transcript.trim().toLowerCase();
    if (shouldSkipRoutineAutoRegister(transcript)) return false;
    if (RoutineAbsenceDetection.isAbsenceOnlyConversation(transcript)) {
      return false;
    }
    if (t.contains('registr') && !transcriptIsMetaRegisterGuidance(transcript)) {
      return true;
    }

    if (interpretationShouldAskAi(type: interp.type, transcript: transcript)) {
      return false;
    }

    if (interp.type == 'sleep') return true;

    switch (interp.type) {
      case 'feeding':
        return !_isFeedingIncompleteForAutoApply(interp, t);
      case 'diaper':
        return !_isDiaperIncompleteForAutoApply(interp, t);
      case 'weight':
      case 'height':
        return _hasConcretePayload(interp);
      case 'symptom':
      case 'consultation':
      case 'vaccine':
        return !transcriptLooksLikeQuestion(transcript);
      default:
        return false;
    }
  }

  static bool _isFeedingIncompleteForAutoApply(
    VoiceRecordInterpretation i,
    String t,
  ) {
    if (routineRecordNeedsClarification(i, t)) return true;
    return false;
  }

  static bool _isDiaperIncompleteForAutoApply(
    VoiceRecordInterpretation i,
    String t,
  ) {
    if (routineRecordNeedsClarification(i, t)) return true;
    return false;
  }

  static bool _hasConcretePayload(VoiceRecordInterpretation i) {
    switch (i.type) {
      case 'feeding':
        return i.feeding?.quantityMl != null ||
            (i.feeding?.subtype?.trim().isNotEmpty ?? false);
      case 'diaper':
        return i.diaper?.kind?.trim().isNotEmpty ?? false;
      case 'weight':
        return i.weight?.weightKg != null;
      case 'height':
        return i.height?.heightCm != null || i.height?.heightDeltaCm != null;
      default:
        return true;
    }
  }
}
