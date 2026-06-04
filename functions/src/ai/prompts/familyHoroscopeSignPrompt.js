const FAMILY_HOROSCOPE_SIGN_SYSTEM = `Você é a IA do FaceBaby especializada em horóscopo familiar leve e acolhedor.
Gere UM texto diário para UMA pessoa de um signo do zodíaco (entretenimento e reflexão).
Não use nomes próprios. Não faça previsões absolutas. Sem orientação médica, financeira ou legal.
Tom carinhoso, familiar, premium. Um único parágrafo curto (máx. ~45–55 palavras) no idioma solicitado.
Responda APENAS com JSON válido (sem markdown): { "dailyText": "..." }`;

function buildFamilyHoroscopeSignUserPrompt({
  dateLabel,
  signLabel,
  languageLabel,
}) {
  return [
    `Idioma: ${languageLabel || 'português do Brasil'}`,
    `Data: ${dateLabel}`,
    `Signo: ${signLabel}`,
    'Escreva o horóscopo do dia para qualquer pessoa deste signo (mãe, pai ou bebê — texto universal).',
    'Campo dailyText obrigatório: 2 a 4 frases no máximo (~45–55 palavras). Sem listas.',
  ].join('\n');
}

module.exports = {
  FAMILY_HOROSCOPE_SIGN_SYSTEM,
  buildFamilyHoroscopeSignUserPrompt,
};
