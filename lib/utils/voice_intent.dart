import 'voice_health_infer.dart';

/// Heurística local para distinguir pergunta de registro de rotina (voz).
bool transcriptLooksLikeQuestion(String transcript) {
  final t = transcript.trim().toLowerCase();
  if (t.isEmpty) return false;
  // "está chorando… febre 37,5" com dúvida no meio ainda é registro de sintoma.
  if (transcriptHasSymptomRegisterCue(t) &&
      (t.contains('febre') || t.contains('chorando') || t.contains('choro'))) {
    return false;
  }
  if (t.contains('?')) return true;

  const registerCues = [
    'mamou',
    'mamei',
    'mamar',
    'dar mamar',
    'troquei',
    'ml',
    'mamadeira',
    'dormiu',
    'dormindo',
    'sono ',
    'soneca',
    'soninho',
    'foi dormir',
    'vai dormir',
    'para dormir',
    'pra dormir',
    'hora de dormir',
    'dormir agora',
    'registrar sono',
    'registre',
    'registrar',
    'iniciar sono',
    'iniciar o sono',
    'colocou para dormir',
    'começou a dormir',
    'acordou',
    'acabou de acordar',
    'despertou',
    'terminou o sono',
    'fralda',
    'xixi',
    'cocô',
    'pesou',
    'quilos',
    'quilo',
    ' kg',
    'gramas',
    'altura',
    'centímetros',
    'centimetros',
    ' cresceu',
    'cresceu ',
    'crescimento',
    'trocou',
    'febre',
    'temperatura',
    'consulta',
    'médico',
    'medico',
    'pediatra',
    'vacin',
    'registrar consulta',
    'registrar vacina',
  ];

  const questionCues = [
    'o que ',
    'o que pode',
    'como ',
    'quanto ',
    'quando ',
    'por que ',
    'porque ',
    'será que ',
    'sabe o que',
    'você sabe',
    'voce sabe',
    'pode ser',
    'queria saber',
    'gostaria de saber',
    'me diz',
    'me fala',
    'me ajuda',
    'é normal',
    'e normal',
    'devo ',
    'preciso ',
    'chorando muito',
    'está chorando',
    'ta chorando',
    'tá chorando',
  ];

  final hasQuestion = questionCues.any(t.contains);
  final hasRegister = registerCues.any(t.contains);

  if (hasQuestion && hasRegister) return true;
  if (hasRegister) return false;

  for (final cue in questionCues) {
    if (t.contains(cue)) return true;
  }

  if (t.startsWith('oi') || t.startsWith('olá') || t.startsWith('ola')) {
    if (t.length > 25) return true;
  }
  return false;
}

bool interpretationShouldAskAi({
  required String type,
  required String transcript,
}) {
  if (transcriptHasSymptomRegisterCue(transcript) &&
      symptomInterpretationFromTranscript(transcript) != null) {
    return false;
  }
  if (type == 'feeding' ||
      type == 'sleep' ||
      type == 'diaper' ||
      type == 'weight' ||
      type == 'height') {
    return false;
  }

  if (type == 'symptom' || type == 'consultation' || type == 'vaccine') {
    if (transcriptLooksLikeQuestion(transcript)) return true;
    return false;
  }

  final t = transcript.trim().toLowerCase();
  if (t.contains('cresceu') ||
      t.contains('crescimento') ||
      t.contains('altura') ||
      t.contains('pesou') ||
      t.contains(' centímetros') ||
      t.contains(' centimetros') ||
      (t.contains('cm') && RegExp(r'\d').hasMatch(t))) {
    return false;
  }
  if ((t.contains('febre') || t.contains('temperatura')) &&
      !transcriptLooksLikeQuestion(transcript)) {
    return false;
  }
  if ((t.contains('consulta') ||
          t.contains('médico') ||
          t.contains('medico') ||
          t.contains('vacin')) &&
      !transcriptLooksLikeQuestion(transcript)) {
    return false;
  }
  if (type == 'question') return true;
  return transcriptLooksLikeQuestion(transcript);
}
