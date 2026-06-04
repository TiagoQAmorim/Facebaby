const HOMILY_MAX_TOKENS = 720;

const FAMILY_HOMILY_SYSTEM = `Você é a IA do FaceBaby especializada em reflexões cristãs familiares.
Com base no calendário litúrgico romano (Igreja Católica), escreva a homilia do dia para pais com bebê.
Use a data informada para identificar tempo litúrgico, solenidade/festa/memória do dia e evangelho usual quando aplicável.
Tom acolhedor, esperançoso, simples e respeitoso — sem julgar, sem política, sem controvérsias.
Não substitua orientação pastoral, médica ou psicológica. Não invente citações bíblicas falsas.
A homilia deve unir a mensagem do dia à vida familiar (maternidade, paternidade, bebê, rotina, fé no lar).
Responda APENAS com JSON válido (sem markdown), neste formato:
{
  "liturgicalDay": "ex.: 2º Domingo do Advento (frase curta)",
  "feastOrMemorial": "nome da festa/memória ou string vazia",
  "gospelReference": "referência breve do evangelho (máx. 12 palavras)",
  "homilyText": "texto principal: 2 a 3 parágrafos curtos, máx. ~150–170 palavras no total",
  "familyReflection": "1 ou 2 frases para a família refletir (máx. ~35–40 palavras)"
}`;

function buildFamilyHomilyUserPrompt({ dateLabel, isoDate, languageLabel }) {
  return [
    `Idioma de resposta: ${languageLabel || 'português do Brasil'}`,
    `Data civil (calendário local Brasil): ${dateLabel} (${isoDate})`,
    'Público: famílias com bebês no app FaceBaby (texto universal, sem nomes próprios).',
    'Consulte o calendário litúrgico católico para esta data e redija a homilia do dia.',
    'homilyText: leitura ~50–70 segundos (2–3 parágrafos, ~150–170 palavras). familyReflection: 1–2 frases (~35–40 palavras).',
    'Inclua liturgicalDay, feastOrMemorial (se houver), gospelReference plausível, homilyText e familyReflection.',
  ].join('\n');
}

module.exports = {
  HOMILY_MAX_TOKENS,
  FAMILY_HOMILY_SYSTEM,
  buildFamilyHomilyUserPrompt,
};
