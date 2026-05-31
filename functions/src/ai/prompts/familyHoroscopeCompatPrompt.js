const FAMILY_HOROSCOPE_COMPAT_SYSTEM = `Você é a IA do FaceBaby. Gere energia familiar e conselho do dia com base nos signos informados.
Tom leve, positivo, acolhedor. Sem previsões absolutas. Sem nomes próprios.
Responda APENAS com JSON válido (sem markdown):
{
  "familyCompatibilityText": "...",
  "familyAdviceText": "..."
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
    'familyCompatibilityText: energia da família considerando esses signos (2 parágrafos curtos).',
    'familyAdviceText: conselho prático do dia para a família (1 parágrafo).',
  ].join('\n');
}

module.exports = {
  FAMILY_HOROSCOPE_COMPAT_SYSTEM,
  buildFamilyHoroscopeCompatUserPrompt,
};
