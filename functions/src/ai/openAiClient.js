/**
 * OpenAI Chat Completions (server-side only).
 * @param {{ apiKey: string, system: string, user: string, maxTokens?: number, temperature?: number, historyMessages?: Array<{role:string,content:string}> }} opts
 */
async function chatCompletion({
  apiKey,
  system,
  user,
  maxTokens = 900,
  temperature = 0.65,
  historyMessages = [],
}) {
  const messages = [
    { role: 'system', content: system },
    ...historyMessages.filter((m) => m?.role && m?.content),
    { role: 'user', content: user },
  ];

  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      temperature,
      max_tokens: maxTokens,
      messages,
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`OpenAI HTTP ${res.status}: ${errText.slice(0, 400)}`);
  }

  const json = await res.json();
  const text = json?.choices?.[0]?.message?.content;
  const tokensUsed = json?.usage?.total_tokens ?? null;
  if (!text || `${text}`.trim() === '') {
    throw new Error('OpenAI returned empty content');
  }
  return { text: `${text}`.trim(), model: json?.model || 'gpt-4o-mini', tokensUsed };
}

/** Limita resposta longa demais (fallback se o modelo ignorar o prompt). */
function clampAiNannyAnswer(text, maxChars = 360) {
  const t = `${text || ''}`.trim();
  if (t.length <= maxChars) return t;
  const cut = t.slice(0, maxChars);
  const lastStop = Math.max(
    cut.lastIndexOf('.'),
    cut.lastIndexOf('!'),
    cut.lastIndexOf('?'),
  );
  if (lastStop > maxChars * 0.5) {
    return cut.slice(0, lastStop + 1).trim();
  }
  return `${cut.trim()}…`;
}

module.exports = { chatCompletion, clampAiNannyAnswer };
