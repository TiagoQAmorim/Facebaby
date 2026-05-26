import '../models/ai/voice_record_interpretation.dart';
import 'voice_growth_infer.dart';
import 'voice_health_infer.dart';
import 'voice_intent.dart';
import 'voice_sleep_infer.dart';

/// Aplica reforço local (crescimento, sono) e corrige resumos errados da OpenAI.
VoiceRecordInterpretation enhanceVoiceRecordInterpretation({
  required VoiceRecordInterpretation interpretation,
  required String transcript,
}) {
  var interp = enhanceVoiceGrowthInterpretation(
    interpretation: interpretation,
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

  if (interp.type == 'question' && transcriptHasSymptomRegisterCue(transcript)) {
    final symptomOnly = symptomInterpretationFromTranscript(transcript);
    if (symptomOnly != null) {
      return _sanitizeSummary(symptomOnly);
    }
  }

  if ((interp.type == 'question' || interp.type == 'unknown') &&
      !interpretationShouldAskAi(type: interp.type, transcript: transcript)) {
    interp = enhanceVoiceGrowthInterpretation(
      interpretation: const VoiceRecordInterpretation.unknown(),
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
  }

  return _sanitizeSummary(interp);
}

bool isUnhelpfulVoiceSummary(String summary) {
  final l = summary.trim().toLowerCase();
  if (l.isEmpty) return false;
  return l.contains('não identificado') ||
      l.contains('nao identificado') ||
      l.contains('não reconhecido') ||
      l.contains('nao reconhecido') ||
      l.contains('ambíguo') ||
      l.contains('ambigu') ||
      l.contains('not related') ||
      l.contains('not recognized');
}

VoiceRecordInterpretation _sanitizeSummary(VoiceRecordInterpretation i) {
  if (!isUnhelpfulVoiceSummary(i.summary)) return i;

  final fallback = _summaryFromPayload(i);
  if (fallback.isEmpty) return i;

  return VoiceRecordInterpretation(
    type: i.type,
    summary: fallback,
    feeding: i.feeding,
    sleep: i.sleep,
    diaper: i.diaper,
    weight: i.weight,
    height: i.height,
    symptom: i.symptom,
    consultation: i.consultation,
    vaccine: i.vaccine,
  );
}

String _summaryFromPayload(VoiceRecordInterpretation i) {
  switch (i.type) {
    case 'height':
      if (i.height != null) {
        if (i.height!.heightCm != null) {
          return 'Altura ${i.height!.heightCm!.toStringAsFixed(0)} cm';
        }
        if (i.height!.heightDeltaCm != null) {
          return 'Crescimento de ${i.height!.heightDeltaCm!.toStringAsFixed(0)} cm';
        }
      }
      return 'Registrar altura / crescimento';
    case 'weight':
      if (i.weight?.weightKg != null) {
        return 'Peso ${i.weight!.weightKg!.toStringAsFixed(2).replaceAll('.', ',')} kg';
      }
      return 'Registrar peso';
    case 'sleep':
      final a = i.sleep?.action ?? 'complete';
      if (a == 'start') return 'Iniciar sono agora';
      if (a == 'end') return 'Encerrar sono e registrar';
      if (i.sleep?.durationMinutes != null) {
        return 'Soneca de ${i.sleep!.durationMinutes} min';
      }
      return 'Registrar sono';
    case 'feeding':
      return 'Registrar alimentação';
    case 'diaper':
      return 'Registrar troca de fralda';
    case 'symptom':
      if (i.symptom?.fever == true && i.symptom?.tempCelsius != null) {
        final temp = i.symptom!.tempCelsius!
            .toStringAsFixed(1)
            .replaceAll('.', ',');
        return 'Febre $temp °C';
      }
      return 'Registrar sintoma / febre';
    case 'consultation':
      final title = i.consultation?.title?.trim() ?? '';
      return title.isNotEmpty ? 'Consulta: $title' : 'Registrar consulta';
    case 'vaccine':
      final name = i.vaccine?.name?.trim() ?? '';
      return name.isNotEmpty ? 'Vacina $name' : 'Registrar vacina';
    default:
      return '';
  }
}

/// Texto exibido no card de confirmação (nunca mostra erro da OpenAI).
String voiceRecordDisplaySummary(VoiceRecordInterpretation i) {
  if (!i.canRegister) return '';
  final s = i.summary.trim();
  if (s.isNotEmpty && !isUnhelpfulVoiceSummary(s)) return s;
  return _summaryFromPayload(i);
}
