const { DateTime } = require('luxon');

const SP = 'America/Sao_Paulo';

const VOICE_INTERPRET_SYSTEM = `Você classifica uma frase falada por pais sobre o bebê (português do Brasil).
Responda APENAS JSON válido (sem markdown).

Tipos de registro (use exatamente estes nomes em inglês no campo type):
- "feeding" — mamada, mamou X ml, peito, mamadeira, solidos
- "sleep" — sono, soneca, dormiu, foi dormir, colocou para dormir, acordou, iniciar/terminar sono
- "diaper" — fralda, xixi, cocô
- "weight" — peso em kg (ex.: "pesou 3,5 kg", "3500 gramas")
- "height" — altura em cm (ex.: "altura 62 cm", "mede 60 centímetros"). Se disser só "cresceu X cm", use height.heightDeltaCm = X (não é pergunta)
- "symptom" — febre, temperatura corporal, sintomas (NÃO confundir com peso em kg). Ex.: "febre 38 graus" → symptom.fever true, symptom.tempCelsius 38
- "consultation" — consulta médica, pediatra, hospital, retorno (agendar ou registrar)
- "vaccine" — vacina aplicada ou agendada (nome da vacina, dose se mencionada)
- "question" — só pergunta pura (NÃO é registro). Frase mista com REGISTRO + dúvida = symptom: ex. "está chorando, não sei o porquê, febre 37,5" → type symptom (fever true, tempCelsius 37.5, crying true), NÃO question
- "febre 38, é normal?" sem relato de registro agora = question
- "unknown" — não classificável
- "multi" — DOIS ou mais registros na MESMA frase (ex.: mamou no peito E trocou fralda com xixi). Preencha feeding E diaper (e outros campos que couberem); summary curto dos dois.

Se houver só um registro, use o type específico (feeding, diaper, etc.), não use "multi".

Não faça diagnóstico. Não prescreva.

Para "question": summary = pergunta reformulada; demais campos null.

SONO (sleep) — campo obrigatório sleep.action:
- "start" — INÍCIO agora: "foi dormir", "colocou para dormir", "começou a dormir", "está dormindo", "iniciar sono", "hora de dormir" (registrar início)
- "end" — FIM agora: "acordou", "acabou de acordar", "despertou", "terminou o sono", "encerrou o sono", "registre que acordou"
- "complete" — período já terminado: "dormiu 1 hora", "soneca de 40 min", "dormiu das 14h às 15h30", "tirou uma soneca"
- NUNCA use "question" para registrar sono. "colocou/ coloquei pra dormir", "hora de dormir", "iniciar sono" = sleep action start.
Para start/end: startedAt e endedAt em geral null (o app usa agora). Para complete: preencha durationMinutes ou startedAt/endedAt.

feeding: subtype peito|mamadeira|solidos; side E|D (obrigatório se peito); quantityMl; note; eventTime (ISO São Paulo ou null=agora). "mamar" sem lado = peito mas side null até a família dizer.
diaper: kind pee|poo|both (obrigatório — não invente se só disse "fralda"); changedAt
weight: weightKg (número em kg, ex. 3.5); measuredAt
height: heightCm (altura atual em cm) OU heightDeltaCm (só o quanto cresceu, ex. 5); measuredAt
symptom: fever (bool); tempCelsius (35-42); occurredAt; otherNote; crying, pain, colic, reflux (bool)
consultation: title (obrigatório, ex. "Pediatra"); occurredAt; notes; phone; address
vaccine: name (obrigatório); dose; appliedAt; nextDueAt; notes

NUNCA classifique temperatura corporal (35-42) como weight. "38 graus" com febre = symptom.

summary: frase curta para a mãe confirmar (ex.: "Febre 38 °C" ou "Consulta pediatra").`;

function buildVoiceInterpretUserPrompt({ transcript, babyName, nowIso }) {
  return `Bebê: ${babyName || 'Bebê'}
Referência de "agora" (São Paulo): ${nowIso}

Frase transcrita:
${transcript}`;
}

/** Normaliza resposta JSON da OpenAI. */
function parseInterpretationJson(raw) {
  let text = `${raw || ''}`.trim();
  if (text.startsWith('```')) {
    text = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
  }
  const parsed = JSON.parse(text);
  const rawType = `${parsed.type || 'unknown'}`.trim().toLowerCase();
  const TYPE_ALIASES = {
    sono: 'sleep',
    soneca: 'sleep',
    dormir: 'sleep',
    alimentacao: 'feeding',
    alimentação: 'feeding',
    mamada: 'feeding',
    fralda: 'diaper',
    peso: 'weight',
    altura: 'height',
    crescimento: 'height',
    pergunta: 'question',
    febre: 'symptom',
    sintoma: 'symptom',
    temperatura: 'symptom',
    consulta: 'consultation',
    medico: 'consultation',
    médico: 'consultation',
    vacina: 'vaccine',
    vacinas: 'vaccine',
  };
  let type = TYPE_ALIASES[rawType] || rawType;
  const hasFeed = parsed.feeding && typeof parsed.feeding === 'object';
  const hasDiaper = parsed.diaper && typeof parsed.diaper === 'object';
  if (type === 'multi' || (hasFeed && hasDiaper)) {
    type = 'feeding';
  }

  let sleep = parsed.sleep;
  if (sleep && typeof sleep === 'object') {
    let action = `${sleep.action || sleep.phase || 'complete'}`.trim().toLowerCase();
    if (['start', 'inicio', 'iniciar', 'iniciou', 'comecou'].includes(action)) {
      action = 'start';
    } else if (['end', 'fim', 'terminou', 'encerrou', 'acordou', 'wake'].includes(action)) {
      action = 'end';
    } else {
      action = 'complete';
    }
    sleep = { ...sleep, action };
  }

  return {
    type,
    summary: `${parsed.summary || ''}`.trim(),
    feeding: parsed.feeding || null,
    sleep,
    diaper: parsed.diaper || null,
    weight: parsed.weight || null,
    height: parsed.height || null,
    symptom: parsed.symptom || null,
    consultation: parsed.consultation || null,
    vaccine: parsed.vaccine || null,
  };
}

function nowSpIso() {
  return DateTime.now().setZone(SP).toISO() || new Date().toISOString();
}

module.exports = {
  VOICE_INTERPRET_SYSTEM,
  buildVoiceInterpretUserPrompt,
  parseInterpretationJson,
  nowSpIso,
  SP,
};
