const AI_INSIGHT_BASE = `Você é a IA Babá do FaceBaby gerando UM insight curto para a família.

REGRAS:
- Máximo 1 frase curta (~12–22 palavras), tom acolhedor e humano.
- Use o nome do bebê.
- Baseie-se APENAS nos dados fornecidos.
- Não diagnostique. Não assuste. Não prescreva.
- Sem emoji no texto (o app adiciona o robô).
- Não repita frases genéricas de blog.`;

const REPLY_LANGUAGE = {
  pt: 'Responda em português do Brasil.',
  en: 'Respond in English.',
  es: 'Responde en español.',
  fr: 'Répondez en français.',
  de: 'Antworten Sie auf Deutsch.',
  it: 'Rispondi in italiano.',
};

function normalizeLocale(locale) {
  const code = `${locale || 'pt'}`.trim().toLowerCase().split(/[-_]/)[0];
  return REPLY_LANGUAGE[code] ? code : 'en';
}

function buildInsightSystem(locale) {
  return `${AI_INSIGHT_BASE}\n${REPLY_LANGUAGE[normalizeLocale(locale)]}`;
}

function buildDailyUserPrompt({ contextBlock, statsBlock, familyHistoryBlock }) {
  const hist =
    familyHistoryBlock && `${familyHistoryBlock}`.trim()
      ? `\nHistórico familiar:\n${familyHistoryBlock.trim()}`
      : '';
  return `Tipo: resumo diário (compare ontem vs anteontem quando possível).

Dados do bebê:
${contextBlock}

Estatísticas recentes:
${statsBlock}${hist}

Gere UMA frase de insight emocional e útil.`;
}

function buildWeeklyUserPrompt({ contextBlock, statsBlock, familyHistoryBlock }) {
  const hist =
    familyHistoryBlock && `${familyHistoryBlock}`.trim()
      ? `\nHistórico familiar:\n${familyHistoryBlock.trim()}`
      : '';
  return `Tipo: resumo semanal (últimos 7 dias vs 7 dias anteriores).

Dados do bebê:
${contextBlock}

Estatísticas:
${statsBlock}${hist}

Gere UMA frase sobre a semana.`;
}

module.exports = {
  buildInsightSystem,
  buildDailyUserPrompt,
  buildWeeklyUserPrompt,
};
