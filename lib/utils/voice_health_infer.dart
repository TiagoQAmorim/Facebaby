import '../models/ai/ai_nanny_parsed_message.dart';
import '../models/ai/voice_record_interpretation.dart';
import '../services/ai/ai_nanny_intent_lexicon.dart';
import '../services/ai/ai_nanny_local_message_parser.dart';
import '../services/ai/ai_nanny_structured_clarification.dart';
import '../services/ai/ai_nanny_structured_mapper.dart';

/// Frase relata sintoma para registrar (mesmo com "não sei o porquê" no meio).
bool transcriptHasSymptomRegisterCue(String transcript) {
  final t = transcript.trim().toLowerCase();
  if (t.isEmpty) return false;
  return AiNannyIntentLexicon.hasTemperatureCue(t) ||
      t.contains('chorando') ||
      t.contains('choro agora') ||
      t.contains('esta chorando') ||
      t.contains('está chorando') ||
      t.contains('ta chorando') ||
      t.contains('tá chorando') ||
      (t.contains('temperatura') && RegExp(r'\d').hasMatch(t));
}

/// Monta registro de sintoma só pelo texto (febre, choro, temperatura).
VoiceRecordInterpretation? symptomInterpretationFromTranscript(String transcript) {
  final parsed = _parseSymptom(transcript.trim().toLowerCase());
  if (parsed == null) return null;
  return VoiceRecordInterpretation(
    type: 'symptom',
    summary: _symptomSummary(parsed),
    symptom: parsed,
  );
}

/// Reforça febre, consulta e vacina quando a IA retorna unknown ou tipo errado.
VoiceRecordInterpretation enhanceVoiceHealthInterpretation({
  required VoiceRecordInterpretation interpretation,
  required String transcript,
}) {
  final t = transcript.trim().toLowerCase();
  if (t.isEmpty) return interpretation;

  if (interpretation.type == 'symptom') {
    return _fillSymptom(interpretation, t);
  }
  if (interpretation.type == 'consultation') {
    return _fillConsultation(interpretation, t);
  }
  if (interpretation.type == 'vaccine') {
    return _fillVaccine(interpretation, t);
  }

  if (interpretation.type == 'weight' && _looksLikeFeverNotWeight(t)) {
    final symptom = _parseSymptom(t);
    if (symptom != null) {
      return VoiceRecordInterpretation(
        type: 'symptom',
        summary: _symptomSummary(symptom),
        symptom: symptom,
      );
    }
  }

  if (interpretation.type != 'question' &&
      interpretation.type != 'feeding' &&
      interpretation.type != 'sleep' &&
      interpretation.type != 'diaper' &&
      interpretation.type != 'weight' &&
      interpretation.type != 'height') {
    final vaccine = _parseVaccine(t);
    if (vaccine != null) {
      return VoiceRecordInterpretation(
        type: 'vaccine',
        summary: _vaccineSummary(vaccine),
        vaccine: vaccine,
      );
    }
    final consultation = _parseConsultation(t);
    if (consultation != null) {
      return VoiceRecordInterpretation(
        type: 'consultation',
        summary: _consultationSummary(consultation),
        consultation: consultation,
      );
    }
    final symptom = _parseSymptom(t);
    if (symptom != null) {
      return VoiceRecordInterpretation(
        type: 'symptom',
        summary: _symptomSummary(symptom),
        symptom: symptom,
      );
    }
  }

  return interpretation;
}

bool _looksLikeFeverNotWeight(String t) {
  return t.contains('febre') ||
      t.contains('temperatura') ||
      t.contains('graus') && (t.contains('febre') || t.contains('temperatura'));
}

VoiceRecordInterpretation _fillSymptom(
  VoiceRecordInterpretation i,
  String t,
) {
  final parsed = _parseSymptom(t) ?? i.symptom;
  if (parsed == null) return i;
  final merged = VoiceSymptomPayload(
    fever: parsed.fever || (i.symptom?.fever ?? false),
    tempCelsius: parsed.tempCelsius ?? i.symptom?.tempCelsius,
    occurredAt: parsed.occurredAt ?? i.symptom?.occurredAt,
    otherNote: parsed.otherNote ?? i.symptom?.otherNote,
    crying: parsed.crying || (i.symptom?.crying ?? false),
    pain: parsed.pain || (i.symptom?.pain ?? false),
  );
  return VoiceRecordInterpretation(
    type: 'symptom',
    summary: _goodSummary(i.summary, _symptomSummary(merged)),
    symptom: merged,
  );
}

VoiceRecordInterpretation _fillConsultation(
  VoiceRecordInterpretation i,
  String t,
) {
  final parsed = _parseConsultation(t);
  final c = i.consultation;
  final merged = VoiceConsultationPayload(
    title: _nonEmpty(parsed?.title) ?? _nonEmpty(c?.title),
    occurredAt: parsed?.occurredAt ?? c?.occurredAt,
    notes: _nonEmpty(parsed?.notes) ?? _nonEmpty(c?.notes),
    phone: _nonEmpty(parsed?.phone) ?? _nonEmpty(c?.phone),
    address: _nonEmpty(parsed?.address) ?? _nonEmpty(c?.address),
  );
  return VoiceRecordInterpretation(
    type: 'consultation',
    summary: _goodSummary(i.summary, _consultationSummary(merged)),
    consultation: merged,
  );
}

VoiceRecordInterpretation _fillVaccine(
  VoiceRecordInterpretation i,
  String t,
) {
  final parsed = _parseVaccine(t);
  final v = i.vaccine;
  final merged = VoiceVaccinePayload(
    name: _nonEmpty(parsed?.name) ?? _nonEmpty(v?.name),
    dose: _nonEmpty(parsed?.dose) ?? _nonEmpty(v?.dose),
    appliedAt: parsed?.appliedAt ?? v?.appliedAt,
    nextDueAt: parsed?.nextDueAt ?? v?.nextDueAt,
    notes: _nonEmpty(parsed?.notes) ?? _nonEmpty(v?.notes),
  );
  return VoiceRecordInterpretation(
    type: 'vaccine',
    summary: _goodSummary(i.summary, _vaccineSummary(merged)),
    vaccine: merged,
  );
}

String? _nonEmpty(String? s) {
  final t = s?.trim() ?? '';
  return t.isEmpty ? null : t;
}

String _goodSummary(String raw, String built) {
  if (built.isEmpty) return raw;
  if (raw.trim().isEmpty || _isBadSummary(raw)) return built;
  return raw;
}

bool _isBadSummary(String raw) {
  final l = raw.toLowerCase();
  return l.contains('não identificado') ||
      l.contains('nao identificado') ||
      l.contains('não reconhecido');
}

VoiceSymptomPayload? _parseSymptom(String t) {
  final hasFever = t.contains('febre') ||
      t.contains('fever') ||
      t.contains('fiebre') ||
      t.contains('fièvre') ||
      t.contains('fieber') ||
      t.contains('febbre') ||
      ((t.contains('temperatura') ||
              t.contains('temperature') ||
              t.contains('temperatur')) &&
          RegExp(r'\d').hasMatch(t));
  final hasSymptomCue = hasFever ||
      t.contains('vomit') ||
      t.contains('vômit') ||
      t.contains('vomito') ||
      t.contains('tosse') ||
      t.contains('chorando') ||
      t.contains('choro') ||
      t.contains('chora') ||
      t.contains('cólica') ||
      t.contains('colica');

  if (!hasSymptomCue) return null;

  final temp = _parseBodyTempC(t);
  final crying = t.contains('chorando') ||
      t.contains('choro agora') ||
      t.contains('esta chorando') ||
      t.contains('está chorando') ||
      t.contains('ta chorando') ||
      t.contains('tá chorando') ||
      (t.contains('chora') && !t.contains('chorar muito'));

  return VoiceSymptomPayload(
    fever: hasFever || temp != null,
    tempCelsius: temp,
    occurredAt: DateTime.now(),
    crying: crying,
    pain: t.contains('dor'),
    colic: t.contains('cólica') || t.contains('colica'),
    reflux: t.contains('refluxo'),
    otherNote: _symptomOtherNote(t),
  );
}

String? _symptomOtherNote(String t) {
  if (t.contains('nao sei') ||
      t.contains('não sei') ||
      t.contains('sem motivo') ||
      t.contains('sem razao') ||
      t.contains('sem razão')) {
    return 'Choro sem motivo aparente (relatado pela família)';
  }
  return null;
}

double? _parseBodyTempC(String t) {
  final patterns = [
    RegExp(r'(?:febre|temperatura)\s*(?:de|é|e|em)?\s*(\d{2})(?:[,.](\d))?\s*(?:graus|°|º)?'),
    RegExp(r'(\d{2})(?:[,.](\d))?\s*(?:graus|°|º)\s*(?:de\s*)?(?:febre|temperatura)'),
    RegExp(r'(\d{2})(?:[,.](\d))?\s*(?:°c|ºc|graus)'),
  ];
  for (final re in patterns) {
    final m = re.firstMatch(t);
    if (m == null) continue;
    final v = _tempFromMatch(m);
    if (v != null && v >= 35 && v <= 42.5) return v;
  }
  if (t.contains('febre') || t.contains('temperatura')) {
    final bare = RegExp(r'\b(3[5-9]|4[0-2])(?:[,.](\d))?\b').firstMatch(t);
    if (bare != null) {
      final v = _tempFromMatch(bare);
      if (v != null && v >= 35 && v <= 42.5) return v;
    }
  }
  return null;
}

double? _tempFromMatch(RegExpMatch m) {
  final whole = int.tryParse(m.group(1) ?? '');
  if (whole == null) return null;
  final frac = m.group(2);
  if (frac == null || frac.isEmpty) return whole.toDouble();
  return whole + int.parse(frac) / 10.0;
}

VoiceConsultationPayload? _parseConsultation(String t) {
  const cues = [
    'consulta',
    'médico',
    'medico',
    'pediatra',
    'dermatolog',
    'hospital',
    'posto',
    'retorno',
    'agend',
  ];
  if (!cues.any(t.contains)) return null;

  String? title;
  if (t.contains('pediatra')) {
    title = 'Pediatra';
  } else if (t.contains('dermatolog')) {
    title = 'Dermatologista';
  } else if (t.contains('hospital')) {
    title = 'Hospital';
  } else if (t.contains('consulta')) {
    title = 'Consulta médica';
  } else {
    title = 'Consulta';
  }

  return VoiceConsultationPayload(
    title: title,
    occurredAt: DateTime.now().add(const Duration(days: 1)),
    notes: null,
  );
}

VoiceVaccinePayload? _parseVaccine(String t) {
  if (!t.contains('vacin')) return null;
  AiNannyStructuredRecord? vaccineRec;
  for (final r in AiNannyLocalMessageParser.parse(t).records) {
    if (r.type == 'vaccine') {
      vaccineRec = r;
      break;
    }
  }
  if (vaccineRec == null) return null;
  final enforced = AiNannyStructuredClarification.enforce(vaccineRec, t);
  return AiNannyStructuredMapper.toInterpretation(enforced)?.vaccine;
}

String _symptomSummary(VoiceSymptomPayload s) {
  if (s.fever && s.tempCelsius != null) {
    final temp = s.tempCelsius!.toStringAsFixed(1).replaceAll('.', ',');
    if (s.crying) return 'Febre $temp °C e choro';
    return 'Febre $temp °C';
  }
  if (s.fever) return 'Registrar febre';
  if (s.crying) return 'Choro sem motivo aparente';
  return 'Registrar sintoma';
}

String _consultationSummary(VoiceConsultationPayload c) {
  final title = c.title?.trim() ?? '';
  if (title.isNotEmpty) return 'Consulta: $title';
  return 'Registrar consulta';
}

String _vaccineSummary(VoiceVaccinePayload v) {
  final name = v.name?.trim() ?? '';
  if (name.isNotEmpty) {
    final dose = v.dose?.trim();
    if (dose != null && dose.isNotEmpty) return 'Vacina $name ($dose)';
    return 'Vacina $name';
  }
  return 'Registrar vacina';
}
