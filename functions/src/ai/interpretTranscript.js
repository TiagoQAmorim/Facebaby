const { chatCompletion } = require('./openAiClient');
const {
  VOICE_INTERPRET_SYSTEM,
  buildVoiceInterpretUserPrompt,
  parseInterpretationJson,
  nowSpIso,
} = require('./prompts/voiceRecordPrompt');

const MAX_TRANSCRIPT_CHARS = 500;

/**
 * Classifica frase (voz ou texto) em tipo de registro via OpenAI.
 * @returns {Promise<{ type: string, summary: string, ... }>}
 */
async function interpretTranscript({
  apiKey,
  transcript,
  babyName = '',
}) {
  const trimmed = `${transcript || ''}`.trim().slice(0, MAX_TRANSCRIPT_CHARS);
  if (!trimmed) {
    return {
      type: 'unknown',
      summary: '',
      feeding: null,
      sleep: null,
      diaper: null,
      weight: null,
      height: null,
      symptom: null,
      consultation: null,
      vaccine: null,
    };
  }

  let interpretation = {
    type: 'unknown',
    summary: trimmed,
    feeding: null,
    sleep: null,
    diaper: null,
    weight: null,
    height: null,
    symptom: null,
    consultation: null,
    vaccine: null,
  };

  try {
    const completion = await chatCompletion({
      apiKey,
      system: VOICE_INTERPRET_SYSTEM,
      user: buildVoiceInterpretUserPrompt({
        transcript: trimmed,
        babyName,
        nowIso: nowSpIso(),
      }),
      maxTokens: 350,
    });
    interpretation = parseInterpretationJson(completion.text);
    if (!interpretation.summary) {
      interpretation.summary = trimmed;
    }
  } catch (err) {
    console.error('interpretTranscript error', err);
    interpretation.summary = trimmed;
  }

  return interpretation;
}

module.exports = { interpretTranscript, MAX_TRANSCRIPT_CHARS };
