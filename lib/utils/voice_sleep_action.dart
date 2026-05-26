import '../services/ai/ai_nanny_intent_lexicon.dart';

/// Normaliza ação de sono (início / fim / período completo) a partir da interpretação ou transcrição.
String normalizeVoiceSleepAction({
  String? fromInterpretation,
  required String transcript,
}) {
  var action = (fromInterpretation ?? '').trim().toLowerCase();
  if (action == 'start' || action == 'end' || action == 'complete') {
    return action;
  }

  final t = transcript.trim().toLowerCase();
  if (t.isEmpty) return 'complete';

  if (transcriptIndicatesWakeEnd(t)) return 'end';

  if (AiNannyIntentLexicon.containsAny(t, AiNannyIntentLexicon.sleepStartCues)) {
    return 'start';
  }

  if (AiNannyIntentLexicon.containsAny(t, AiNannyIntentLexicon.sleepCompleteCues)) {
    return 'complete';
  }

  if ((t.contains('sono') ||
          t.contains('sleep') ||
          t.contains('sueño') ||
          t.contains('schlaf')) &&
      _parseDurationInTranscript(t) != null) {
    return 'complete';
  }

  return 'complete';
}

int? _parseDurationInTranscript(String t) {
  final h = RegExp(r'(\d+)\s*(?:h|horas?|hours?)').firstMatch(t);
  final m = RegExp(r'(\d+)\s*(?:min|minutos?|minutes?)').firstMatch(t);
  var total = 0;
  if (h != null) total += (int.tryParse(h.group(1) ?? '') ?? 0) * 60;
  if (m != null) total += int.tryParse(m.group(1) ?? '') ?? 0;
  return total > 0 ? total : null;
}

/// Frase indica que o bebê acordou agora (encerrar sono em andamento).
bool transcriptIndicatesWakeEnd(String transcript) {
  final t = transcript.trim().toLowerCase();
  if (t.isEmpty) return false;
  return AiNannyIntentLexicon.containsAny(t, AiNannyIntentLexicon.sleepWakeCues);
}
