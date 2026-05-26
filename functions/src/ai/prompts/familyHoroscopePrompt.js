const FAMILY_HOROSCOPE_SYSTEM = `Você é a IA do FaceBaby especializada em criar conteúdo afetivo e familiar baseado em signos.
Gere um horóscopo diário leve, positivo e acolhedor para uma família com bebê.
Use os signos informados apenas como entretenimento e reflexão.
Não faça previsões absolutas. Não dê orientação médica, financeira ou legal. Não assuste os pais.
Escreva em português do Brasil, com tom carinhoso, familiar e premium.
Cada texto deve ter no máximo 3 parágrafos curtos, linguagem simples, sem misticismo pesado.
Foco em vínculo, carinho, rotina e harmonia familiar.

Responda APENAS com JSON válido (sem markdown), neste formato exato:
{
  "motherText": "...",
  "fatherText": "... ou string vazia se não houver pai",
  "babyText": "...",
  "familyCompatibilityText": "...",
  "familyAdviceText": "..."
}`;

function buildFamilyHoroscopeUserPrompt({
  dateLabel,
  motherName,
  motherSign,
  fatherName,
  fatherSign,
  babyName,
  babySign,
}) {
  const lines = [
    `Data de referência: ${dateLabel}`,
    `Mãe: ${motherName || 'Mamãe'} — signo ${motherSign || 'não informado'}`,
  ];
  if (fatherSign) {
    lines.push(`Pai: ${fatherName || 'Papai'} — signo ${fatherSign}`);
  } else {
    lines.push('Pai: não cadastrado (deixe fatherText como string vazia).');
  }
  lines.push(`Bebê: ${babyName || 'Bebê'} — signo ${babySign || 'não informado'}`);
  lines.push(
    'Gere: (1) texto para a mãe, (2) texto para o pai se existir, (3) texto para o bebê, (4) energia da família hoje considerando os signos, (5) conselho prático do dia.',
  );
  return lines.join('\n');
}

module.exports = { FAMILY_HOROSCOPE_SYSTEM, buildFamilyHoroscopeUserPrompt };
