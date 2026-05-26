import '../models/ai/voice_record_interpretation.dart';
import '../services/ai/ai_nanny_intent_lexicon.dart';
import 'voice_health_infer.dart';
import 'voice_record_clarification.dart';

/// Vários registros na mesma frase (ex.: mamou e trocou fralda).
List<VoiceRecordInterpretation> expandRoutineInterpretations({
  required VoiceRecordInterpretation primary,
  required String transcript,
}) {
  final low = transcript.trim().toLowerCase();
  if (low.isEmpty) {
    return primary.canRegister && primary.type != 'question' ? [primary] : [];
  }

  final symptom = symptomInterpretationFromTranscript(transcript);
  final wantFeed =
      transcriptHasFeedingCue(low) || primary.type == 'feeding' || primary.feeding != null;
  final wantDiaper =
      transcriptHasDiaperCue(low) || primary.type == 'diaper' || primary.diaper != null;

  if (symptom != null && !wantFeed && !wantDiaper) {
    return [symptom];
  }

  if (!wantFeed && !wantDiaper) {
    if (symptom != null) return [symptom];
    return primary.canRegister && primary.type != 'question' ? [primary] : [];
  }

  final out = <VoiceRecordInterpretation>[];
  if (symptom != null) out.add(symptom);
  if (wantFeed) {
    out.add(_feedingInterpretation(primary, low));
  }
  if (wantDiaper) {
    out.add(_diaperInterpretation(primary, low));
  }
  return out;
}

bool transcriptHasFeedingCue(String low) =>
    AiNannyIntentLexicon.hasFeedingCue(low);

bool transcriptHasDiaperCue(String low) => AiNannyIntentLexicon.hasDiaperCue(low);

VoiceRecordInterpretation _feedingInterpretation(
  VoiceRecordInterpretation primary,
  String low,
) {
  if (primary.type == 'feeding' && primary.feeding != null) {
    final f = primary.feeding!;
    final subtype = (f.subtype?.trim().isNotEmpty ?? false)
        ? f.subtype!.trim().toLowerCase()
        : _inferFeedingSubtype(low);
    return primary.copyWith(
      feeding: VoiceFeedingPayload(
        subtype: subtype,
        side: parseBreastSideFromTranscript(f.side, low),
        quantityMl: f.quantityMl,
        note: f.note,
        eventTime: f.eventTime,
      ),
      summary: primary.summary.isNotEmpty ? primary.summary : 'Mamada registrada',
    );
  }

  return VoiceRecordInterpretation(
    type: 'feeding',
    summary: 'Mamada registrada',
    feeding: VoiceFeedingPayload(
      subtype: _inferFeedingSubtype(low),
      side: parseBreastSideFromTranscript(null, low),
      eventTime: DateTime.now(),
    ),
  );
}

VoiceRecordInterpretation _diaperInterpretation(
  VoiceRecordInterpretation primary,
  String low,
) {
  if (primary.type == 'diaper' && primary.diaper != null) {
    final d = primary.diaper!;
    final kind = resolveDiaperKindFromTranscript(d.kind, low);
    return primary.copyWith(
      diaper: VoiceDiaperPayload(
        kind: kind,
        changedAt: d.changedAt ?? DateTime.now(),
      ),
      summary: primary.summary.isNotEmpty ? primary.summary : 'Troca de fralda',
    );
  }

  final kind = resolveDiaperKindFromTranscript(null, low);
  return VoiceRecordInterpretation(
    type: 'diaper',
    summary: 'Troca de fralda',
    diaper: VoiceDiaperPayload(
      kind: kind,
      changedAt: DateTime.now(),
    ),
  );
}

String _inferFeedingSubtype(String low) {
  if (AiNannyIntentLexicon.isBottleSubtype(low)) return 'mamadeira';
  if (AiNannyIntentLexicon.isSolidsSubtype(low)) return 'solidos';
  return 'peito';
}

