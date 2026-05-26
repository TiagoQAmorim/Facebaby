/**
 * OpenAI Text-to-Speech — voz natural (gpt-4o-mini-tts) com fallback tts-1-hd.
 */

const TTS_INSTRUCTIONS_PT =
  'Fale em português do Brasil com tom acolhedor, calmo e natural, como uma babá ' +
  'experiente conversando com os pais. Ritmo moderado, articulação clara, sem soar robótica.';

const TTS_INSTRUCTIONS_EN =
  'Speak in warm, natural English like a caring baby nurse talking to parents. ' +
  'Moderate pace, clear and gentle, not robotic.';

/** Vozes recomendadas para gpt-4o-mini-tts (marin/cedar = melhor qualidade). */
function voiceForLocale(locale, model) {
  const code = `${locale || 'pt'}`.trim().toLowerCase().split(/[-_]/)[0];
  const hdOnly = model === 'tts-1-hd' || model === 'tts-1';
  if (hdOnly) {
    switch (code) {
      case 'en':
        return 'coral';
      case 'es':
      case 'it':
      case 'fr':
      case 'de':
        return 'nova';
      case 'pt':
      default:
        return 'coral';
    }
  }
  switch (code) {
    case 'en':
      return 'coral';
    case 'es':
    case 'it':
    case 'fr':
    case 'de':
    case 'pt':
    default:
      return 'marin';
  }
}

function instructionsForLocale(locale) {
  const code = `${locale || 'pt'}`.trim().toLowerCase().split(/[-_]/)[0];
  if (code === 'en') return TTS_INSTRUCTIONS_EN;
  if (code === 'pt') return TTS_INSTRUCTIONS_PT;
  return (
    'Speak naturally in the user language with a warm, calm baby-care tone. ' +
    'Moderate pace, not robotic.'
  );
}

async function requestTts({
  apiKey,
  model,
  input,
  voice,
  speed,
  instructions,
}) {
  const body = {
    model,
    input: input.slice(0, 4096),
    voice,
    speed: Math.min(1.15, Math.max(0.9, speed)),
    response_format: 'mp3',
  };
  if (instructions && model.includes('gpt-4o-mini-tts')) {
    body.instructions = instructions.slice(0, 4096);
  }

  const res = await fetch('https://api.openai.com/v1/audio/speech', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`OpenAI TTS HTTP ${res.status}: ${errText.slice(0, 400)}`);
  }

  const arrayBuffer = await res.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);
  if (!buffer.length) {
    throw new Error('OpenAI TTS retornou áudio vazio.');
  }
  return { buffer, mimeType: 'audio/mpeg', model, voice };
}

/**
 * @param {{ apiKey: string, text: string, voice?: string, speed?: number, locale?: string }} opts
 */
async function synthesizeSpeech({
  apiKey,
  text,
  voice,
  speed = 1.0,
  locale = 'pt',
}) {
  const input = `${text || ''}`.trim();
  if (!input) {
    throw new Error('TTS input vazio.');
  }

  const loc = `${locale || 'pt'}`.trim();
  const instructions = instructionsForLocale(loc);

  // tts-1-hd primeiro (mais rápido); gpt-4o-mini-tts se falhar (mais natural).
  const attempts = [
    {
      model: 'tts-1-hd',
      voice: voiceForLocale(loc, 'tts-1-hd'),
      instructions: null,
    },
    {
      model: 'gpt-4o-mini-tts',
      voice: voice || voiceForLocale(loc, 'gpt-4o-mini-tts'),
      instructions,
    },
  ];

  let lastErr;
  for (const attempt of attempts) {
    try {
      return await requestTts({
        apiKey,
        model: attempt.model,
        input,
        voice: attempt.voice,
        speed,
        instructions: attempt.instructions,
      });
    } catch (err) {
      lastErr = err;
      console.warn(
        `OpenAI TTS fallback: ${attempt.model}/${attempt.voice} failed:`,
        err?.message || err,
      );
    }
  }

  throw lastErr || new Error('OpenAI TTS falhou.');
}

module.exports = { synthesizeSpeech, voiceForLocale, instructionsForLocale };
