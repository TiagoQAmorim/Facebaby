const FAMILY_HOROSCOPE_COMPAT_SYSTEM = `Você é a IA do FaceBaby. Gere energia familiar e conselho do dia com base nos signos informados.
Tom leve, positivo, acolhedor. Sem previsões absolutas. Sem nomes próprios. Textos curtos para leitura no telemóvel.
Responda APENAS com JSON válido (sem markdown):
{
  "familyCompatibilityText": "1 parágrafo curto (máx. ~50 palavras)",
  "familyAdviceText": "2 ou 3 frases práticas (máx. ~35 palavras)"
}`;

function buildFamilyHoroscopeCompatUserPrompt({
  dateLabel,
  signsLabel,
  languageLabel,
}) {
  return [
    `Idioma: ${languageLabel || 'português do Brasil'}`,
    `Data: ${dateLabel}`,
    `Signos da família hoje: ${signsLabel}`,
    'familyCompatibilityText: energia da família hoje (1 parágrafo, ~50 palavras).',
    'familyAdviceText: conselho prático do dia (2–3 frases, ~35 palavras).',
  ].join('\n');
}

module.exports = {
  FAMILY_HOROSCOPE_COMPAT_SYSTEM,
  buildFamilyHoroscopeCompatUserPrompt,
};
