/** Máximo salvo no Firestore / app. */
const MAX_AI_HISTORY = 1500;

/** Máximo enviado no prompt da OpenAI (economia de tokens). */
const MAX_PROMPT_AI_HISTORY = 750;

/**
 * Trunca histórico para o prompt sem perder o início (mais relevante).
 * @param {string} raw
 * @returns {string}
 */
function formatHistoryForPrompt(raw) {
  const text = `${raw || ''}`.trim().slice(0, MAX_AI_HISTORY);
  if (!text) return '';
  if (text.length <= MAX_PROMPT_AI_HISTORY) return text;
  return `${text.slice(0, MAX_PROMPT_AI_HISTORY).trimEnd()}…`;
}

/**
 * @param {import('firebase-admin/firestore').Firestore} db
 * @param {string} uid
 */
async function fetchFamilyAiHistory(db, uid) {
  const snap = await db.collection('ai_profiles').doc(uid).get();
  if (!snap.exists) return '';
  const raw = `${snap.data()?.aiHistory || ''}`.trim();
  return formatHistoryForPrompt(raw);
}

module.exports = {
  fetchFamilyAiHistory,
  formatHistoryForPrompt,
  MAX_AI_HISTORY,
  MAX_PROMPT_AI_HISTORY,
};
