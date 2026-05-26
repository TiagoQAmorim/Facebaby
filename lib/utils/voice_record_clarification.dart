import '../i18n/app_i18n.dart';
import '../models/ai/voice_record_interpretation.dart';
import '../services/ai/ai_nanny_intent_lexicon.dart';
import 'voice_routine_multi_infer.dart' show transcriptHasFeedingCue;

/// Família não quer completar o registro pendente.
bool transcriptDeclinesRoutineRegistration(String transcript) {
  final low = transcript.trim().toLowerCase();
  if (low.isEmpty) return false;
  return AiNannyIntentLexicon.containsAny(
    low,
    AiNannyIntentLexicon.declineRegistrationCues,
  );
}

/// Registro de rotina ainda sem dados obrigatórios para gravar.
bool routineRecordNeedsClarification(
  VoiceRecordInterpretation i,
  String transcript,
) {
  switch (i.type) {
    case 'feeding':
      return !_isFeedingComplete(i, transcript);
    case 'diaper':
      return !_isDiaperComplete(i, transcript);
    default:
      return false;
  }
}

bool _isFeedingComplete(VoiceRecordInterpretation i, String transcript) {
  final low = transcript.toLowerCase();
  final f = i.feeding;
  var subtype = (f?.subtype ?? '').trim().toLowerCase();
  if (subtype.isEmpty) {
    if (AiNannyIntentLexicon.isBottleSubtype(low) ||
        RegExp(r'\d+\s*ml').hasMatch(low)) {
      subtype = 'mamadeira';
    } else if (transcriptHasFeedingCue(low)) {
      subtype = 'peito';
    } else {
      return false;
    }
  }
  if (subtype == 'mamadeira' || subtype == 'solidos') return true;
  if (subtype == 'peito') {
    if (parseBreastSideFromTranscript(f?.side, low) == null) return false;
    return feedingHasExplicitDuration(i, transcript);
  }
  return false;
}

/// Duração informada na fala ou na nota do rascunho (não usa default do app).
bool feedingHasExplicitDuration(
  VoiceRecordInterpretation i,
  String transcript,
) {
  final note = i.feeding?.note ?? '';
  return parseFeedingDurationMinutes(transcript.toLowerCase()) != null ||
      parseFeedingDurationMinutes(note.toLowerCase()) != null;
}

bool _isDiaperComplete(VoiceRecordInterpretation i, String transcript) {
  final kind = resolveDiaperKindFromTranscript(i.diaper?.kind, transcript);
  if (kind != 'pee' && kind != 'poo' && kind != 'both') return false;
  if (diaperNeedsChangeConfirmation(transcript)) return false;
  return true;
}

/// Só xixi/cocô na frase, sem troca — confirmar antes de salvar.
bool diaperNeedsChangeConfirmation(String transcript) {
  final low = transcript.trim().toLowerCase();
  if (transcriptIndicatesDiaperChange(low)) return false;
  final kind = resolveDiaperKindFromTranscript(null, transcript);
  return kind != null;
}

bool transcriptIndicatesDiaperChange(String low) {
  return low.contains('troquei') ||
      low.contains('trocou') ||
      low.contains('trocar') ||
      low.contains('troca de fralda') ||
      low.contains('trocar a fralda') ||
      low.contains('fralda');
}

bool transcriptConfirmsAffirmative(String transcript) {
  final low = transcript.trim().toLowerCase();
  if (low.isEmpty) return false;
  if (RegExp(r'^(sim|s|ok|confirmo)\b').hasMatch(low)) return true;
  if (RegExp(r'\bsim\b').hasMatch(low)) return true;
  if (low.contains('pode ser') || low.contains('confirmo')) return true;
  if (low.contains('agora') ||
      low.contains('troquei') ||
      low.contains('trocou') ||
      transcriptIndicatesDiaperChange(low)) {
    return true;
  }
  return false;
}

/// Dados obrigatórios já preenchidos no rascunho (após resposta parcial da família).
bool isRoutineRecordComplete(
  VoiceRecordInterpretation i, [
  String? transcript,
]) {
  final t = transcript ?? '';
  switch (i.type) {
    case 'feeding':
      final f = i.feeding;
      var sub = (f?.subtype ?? '').trim().toLowerCase();
      if (sub != 'peito' && sub != 'mamadeira' && sub != 'solidos') {
        return false;
      }
      if (sub == 'mamadeira' || sub == 'solidos') return true;
      final side = (f?.side ?? '').trim().toUpperCase();
      if (side != 'E' && side != 'D') return false;
      return feedingHasExplicitDuration(i, t);
    case 'diaper':
      final k = (i.diaper?.kind ?? '').trim().toLowerCase();
      if (k != 'pee' && k != 'poo' && k != 'both') return false;
      if (diaperNeedsChangeConfirmation(t) &&
          !transcriptConfirmsAffirmative(t)) {
        return false;
      }
      return true;
    default:
      return !routineRecordNeedsClarification(i, t);
  }
}

/// Perguntas para a IA / família — sempre lista mamada E fralda quando ambos faltam.
String buildClarificationPrompt(
  List<VoiceRecordInterpretation> events,
  String transcript,
  S strings,
) {
  final lines = <String>[];
  for (final e in events) {
    if (isRoutineRecordComplete(e, transcript)) continue;

    switch (e.type) {
      case 'feeding':
        lines.addAll(_feedingClarifyLines(e, transcript, strings));
        break;
      case 'diaper':
        if (!isRoutineRecordComplete(e, transcript)) {
          if (resolveDiaperKindFromTranscript(e.diaper?.kind, transcript) ==
              null) {
            lines.add(
              '${strings.aiClarifyDiaperPrefix} ${strings.aiClarifyDiaperKind}',
            );
          } else if (diaperNeedsChangeConfirmation(transcript)) {
            lines.add(
              '${strings.aiClarifyDiaperPrefix} ${strings.aiClarifyDiaperChangeNow}',
            );
          }
        }
        break;
      default:
        break;
    }
  }
  if (lines.isEmpty) return '';
  if (lines.length == 1) return lines.single;
  return lines
      .asMap()
      .entries
      .map((e) => '${e.key + 1}) ${e.value}')
      .join(' ');
}

List<String> _feedingClarifyLines(
  VoiceRecordInterpretation e,
  String transcript,
  S strings,
) {
  final f = e.feeding;
  final sub = (f?.subtype ?? '').trim().toLowerCase();
  final low = transcript.toLowerCase();
  if (sub == 'mamadeira' || sub == 'solidos') return const [];

  final out = <String>[];
  final prefix = strings.aiClarifyFeedingPrefix;

  if (sub.isEmpty &&
      !low.contains('mamadeira') &&
      !transcriptHasFeedingCue(low)) {
    out.add('$prefix ${strings.aiClarifyFeedingType}');
    return out;
  }

  final side = parseBreastSideFromTranscript(f?.side, low);
  if (side == null) {
    out.add('$prefix ${strings.aiClarifyBreastSide}');
  }
  if (!feedingHasExplicitDuration(e, transcript)) {
    out.add('$prefix ${strings.aiClarifyFeedingDuration}');
  }
  return out;
}

/// Aplica respostas curtas ao rascunho pendente (ex.: "esquerdo e xixi").
List<VoiceRecordInterpretation> applyClarificationsToPending(
  List<VoiceRecordInterpretation> pending,
  String reply,
) {
  final low = reply.trim().toLowerCase();
  return pending.map((e) {
    switch (e.type) {
      case 'feeding':
        return _applyFeedingClarification(e, low);
      case 'diaper':
        return _applyDiaperClarification(e, low);
      default:
        return e;
    }
  }).toList();
}

VoiceRecordInterpretation _applyFeedingClarification(
  VoiceRecordInterpretation e,
  String low,
) {
  var subtype = (e.feeding?.subtype ?? '').trim().toLowerCase();
  if (AiNannyIntentLexicon.isBottleSubtype(low) ||
      RegExp(r'\d+\s*ml').hasMatch(low)) {
    subtype = 'mamadeira';
  } else if (transcriptHasFeedingCue(low) ||
      low.contains('peito') ||
      subtype.isEmpty ||
      subtype == 'peito') {
    subtype = 'peito';
  }
  final side = parseBreastSideFromTranscript(e.feeding?.side, low);
  final mins = parseFeedingDurationMinutes(low);
  var note = e.feeding?.note;
  if (mins != null) {
    final durNote = '$mins min';
    note = note == null || note.isEmpty ? durNote : '$note · $durNote';
  }
  return e.copyWith(
    feeding: VoiceFeedingPayload(
      subtype: subtype,
      side: side,
      quantityMl: e.feeding?.quantityMl,
      note: note,
      eventTime: e.feeding?.eventTime ?? DateTime.now(),
    ),
  );
}

/// Ex.: "5 minutos", "5 min", "cinco minutos" (só dígitos).
int? parseFeedingDurationMinutes(String low) {
  final m = RegExp(r'(\d{1,3})\s*(?:min(?:utos?)?|m\b)').firstMatch(low);
  if (m != null) {
    final n = int.tryParse(m.group(1) ?? '');
    if (n != null && n > 0 && n <= 180) return n;
  }
  return null;
}

VoiceRecordInterpretation _applyDiaperClarification(
  VoiceRecordInterpretation e,
  String low,
) {
  final kind = resolveDiaperKindFromTranscript(e.diaper?.kind, low);
  final at = transcriptConfirmsAffirmative(low)
      ? DateTime.now()
      : (e.diaper?.changedAt ?? DateTime.now());
  return e.copyWith(
    diaper: VoiceDiaperPayload(
      kind: kind,
      changedAt: at,
    ),
  );
}

String? parseBreastSideFromTranscript(String? fromPayload, String low) {
  final p = (fromPayload ?? '').trim().toUpperCase();
  if (p == 'E' || p == 'D') return p;
  return AiNannyIntentLexicon.parseBreastSide(low);
}

String? resolveDiaperKindFromTranscript(String? fromPayload, String transcript) {
  var k = (fromPayload ?? '').trim().toLowerCase();
  if (k == 'pee' || k == 'poo' || k == 'both') return k;
  return AiNannyIntentLexicon.resolveDiaperKind(transcript);
}
