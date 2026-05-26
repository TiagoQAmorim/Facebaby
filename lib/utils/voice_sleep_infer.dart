import '../models/ai/voice_record_interpretation.dart';
import '../services/ai/ai_nanny_intent_lexicon.dart';
import 'voice_sleep_action.dart' show normalizeVoiceSleepAction, transcriptIndicatesWakeEnd;

/// Reforça type sleep + action + duração quando a IA retorna unknown ou dados incompletos.
VoiceRecordInterpretation enhanceVoiceSleepInterpretation({
  required VoiceRecordInterpretation interpretation,
  required String transcript,
}) {
  final t = transcript.trim().toLowerCase();
  if (t.isEmpty) return interpretation;

  if (interpretation.type == 'sleep') {
    return _fillSleep(interpretation, transcript);
  }

  if (transcriptIndicatesWakeEnd(t)) {
    return VoiceRecordInterpretation(
      type: 'sleep',
      summary: interpretation.summary.isNotEmpty
          ? interpretation.summary
          : 'Encerrar sono e registrar',
      sleep: const VoiceSleepPayload(action: 'end'),
    );
  }

  if (interpretation.canRegister && interpretation.type != 'unknown') {
    return interpretation;
  }

  if (!_looksLikeSleepRegister(t)) return interpretation;

  final action = normalizeVoiceSleepAction(
    fromInterpretation: null,
    transcript: transcript,
  );
  final duration = _parseDurationMinutes(t);

  return VoiceRecordInterpretation(
    type: 'sleep',
    summary: interpretation.summary.isNotEmpty
        ? interpretation.summary
        : _sleepSummary(action, duration),
    sleep: VoiceSleepPayload(
      action: action,
      durationMinutes: duration,
    ),
  );
}

VoiceRecordInterpretation _fillSleep(
  VoiceRecordInterpretation i,
  String t,
) {
  final action = normalizeVoiceSleepAction(
    fromInterpretation: i.sleep?.action,
    transcript: t,
  );
  final duration = i.sleep?.durationMinutes ?? _parseDurationMinutes(t);
  var summary = i.summary;
  if (summary.isEmpty) {
    summary = _sleepSummary(action, duration);
  }
  return VoiceRecordInterpretation(
    type: 'sleep',
    summary: summary,
    sleep: VoiceSleepPayload(
      action: action,
      startedAt: i.sleep?.startedAt,
      endedAt: i.sleep?.endedAt,
      durationMinutes: duration,
      note: i.sleep?.note,
    ),
  );
}

bool _looksLikeSleepRegister(String t) =>
    AiNannyIntentLexicon.hasSleepCue(t) ||
    t.contains('registre') ||
    t.contains('registrar') ||
    t.contains('register');

int? _parseDurationMinutes(String t) {
  var total = 0;
  var found = false;

  final hours = RegExp(r'(\d+)\s*(?:h|horas?|hours?)\b').allMatches(t);
  for (final m in hours) {
    final h = int.tryParse(m.group(1) ?? '');
    if (h != null && h > 0 && h < 24) {
      total += h * 60;
      found = true;
    }
  }

  final mins =
      RegExp(r'(\d+)\s*(?:min(?:utos?)?|minutes?|m)\b').allMatches(t);
  for (final m in mins) {
    final n = int.tryParse(m.group(1) ?? '');
    if (n != null && n > 0 && n < 600) {
      total += n;
      found = true;
    }
  }

  if (!found) {
    final alone = RegExp(
      r'(?:dormiu|soneca|sono|dormindo)\s*(?:de\s*)?(\d{1,3})\s*(?:min)?',
    ).firstMatch(t);
    if (alone != null) {
      final n = int.tryParse(alone.group(1) ?? '');
      if (n != null && n > 0 && n < 600) {
        total = n;
        found = true;
      }
    }
  }

  return found && total > 0 ? total : null;
}

String _sleepSummary(String action, int? durationMinutes) {
  switch (action) {
    case 'start':
      return 'Iniciar sono agora';
    case 'end':
      return 'Encerrar sono e registrar';
    default:
      if (durationMinutes != null && durationMinutes > 0) {
        if (durationMinutes >= 60) {
          final h = durationMinutes ~/ 60;
          final m = durationMinutes % 60;
          if (m == 0) return 'Soneca de $h h';
          return 'Soneca de $h h e $m min';
        }
        return 'Soneca de $durationMinutes min';
      }
      return 'Registrar período de sono';
  }
}
