/**
 * OpenAI Text-to-Speech — perfis de voz da IA Babá (babá gentil por defeito).
 */

const VOICE_STYLES = {
  gentleNanny: 'gentleNanny',
  neutralAssistant: 'neutralAssistant',
  energetic: 'energetic',
};

/** Vozes femininas suaves (gpt-4o-mini-tts). Evitar "coral" em PT — soa mais animada/regional. */
function voiceForProfile(locale, style) {
  const code = `${locale || 'pt'}`.trim().toLowerCase().split(/[-_]/)[0];
  const s = VOICE_STYLES[style] ? style : VOICE_STYLES.gentleNanny;

  if (s === VOICE_STYLES.energetic) {
    return code === 'en' ? 'coral' : 'nova';
  }
  if (s === VOICE_STYLES.neutralAssistant) {
    return 'nova';
  }

  // Babá gentil — voz madura, macia, acolhedora.
  switch (code) {
    case 'en':
      return 'shimmer';
    case 'es':
      return 'shimmer';
    case 'fr':
      return 'shimmer';
    case 'de':
      return 'sage';
    case 'it':
      return 'shimmer';
    case 'pt':
    default:
      return 'shimmer';
  }
}

/** Fallback tts-1-hd (sem instructions). */
function voiceForHdFallback(locale) {
  const code = `${locale || 'pt'}`.trim().toLowerCase().split(/[-_]/)[0];
  switch (code) {
    case 'en':
      return 'nova';
    case 'pt':
    default:
      return 'nova';
  }
}

function defaultSpeedForStyle(style, clientSpeed) {
  const s = VOICE_STYLES[style] ? style : VOICE_STYLES.gentleNanny;
  let base = 0.94;
  if (s === VOICE_STYLES.neutralAssistant) base = 1.0;
  if (s === VOICE_STYLES.energetic) base = 1.05;
  const rate = typeof clientSpeed === 'number' && !Number.isNaN(clientSpeed)
    ? clientSpeed
    : base;
  return Math.min(1.08, Math.max(0.88, rate));
}

const INSTRUCTIONS = {
  gentleNanny: {
    pt:
      'Fale em português do Brasil, sotaque neutro de São Paulo (urbano, sem sotaque caipira, ' +
      'interiorano ou caricato). Você é uma babá experiente de cerca de 50 anos: calma, macia, ' +
      'acolhedora e afetuosa, como uma cuidadora maternal que tranquiliza os pais à noite. ' +
      'Tom de voz baixo e suave, ritmo lento (cerca de 94% do normal), pausas naturais após ' +
      'vírgulas e frases. Energia contida, sem animação de desenho, GPS, call center, TikTok ' +
      'ou assistente corporativo. Articulação clara e gentil, com cadência de respiração natural. ' +
      'Não seja robótica nem exageradamente alegre.',
    en:
      'Speak in warm American English like an experienced nanny in her fifties: calm, soft, ' +
      'gentle and emotionally safe for tired parents at night. Moderate-slow pace with natural ' +
      'pauses after commas and sentences. Low energy, caring tone — not corporate assistant, ' +
      'GPS, cartoon or influencer voice. Clear articulation, smooth and comforting.',
    es:
      'Habla en español latinoamericano neutro, con tono de niñera experimentada: cálida, suave, ' +
      'tranquila y cariñosa. Ritmo lento y natural, pausas suaves, sin dramatismo ni voz robótica. ' +
      'Evita acento exagerado o entonación de GPS.',
    fr:
      'Parlez en français avec une voix féminine douce et chaleureuse, comme une nourrice ' +
      'expérimentée et rassurante. Rythme lent, pauses naturelles, ton calme et affectueux — ' +
      'pas style GPS ni assistant formel.',
    de:
      'Sprechen Sie auf Deutsch mit einer warmen, ruhigen Betreuungston — erfahrene, fürsorgliche ' +
      'Stimme einer Babysitterin um die 50. Langsames Tempo, weiche Betonung, keine harte oder ' +
      'robotische GPS-Stimme.',
    it:
      'Parla in italiano con tono da babysitter esperta e affettuosa (ispirazione nonna ' +
      'premurosa, senza teatralità): calma, dolce, lenta, con pause naturali. Non vocce ' +
      'robotica o troppo allegra.',
  },
  neutralAssistant: {
    pt: 'Português do Brasil claro e neutro. Tom profissional e amigável, ritmo moderado.',
    en: 'Clear neutral English. Professional friendly tone, moderate pace.',
    es: 'Español neutro claro. Tono profesional amable, ritmo moderado.',
    fr: 'Français clair et neutre. Ton professionnel, rythme modéré.',
    de: 'Klares neutrales Deutsch. Professioneller freundlicher Ton.',
    it: 'Italiano chiaro e neutro. Tono professionale, ritmo moderato.',
  },
  energetic: {
    pt: 'Português do Brasil animado mas claro. Tom positivo e acolhedor, ritmo um pouco mais rápido.',
    en: 'Upbeat clear English. Warm and positive, slightly faster pace.',
    es: 'Español claro y animado. Tono positivo, ritmo un poco más rápido.',
    fr: 'Français clair et dynamique. Ton positif.',
    de: 'Deutsch klar und lebhaft. Positiver Ton.',
    it: 'Italiano chiaro e vivace. Tono positivo.',
  },
};

function instructionsForLocale(locale, style) {
  const code = `${locale || 'pt'}`.trim().toLowerCase().split(/[-_]/)[0];
  const s = VOICE_STYLES[style] ? style : VOICE_STYLES.gentleNanny;
  const block = INSTRUCTIONS[s] || INSTRUCTIONS.gentleNanny;
  return block[code] || block.pt || INSTRUCTIONS.gentleNanny.pt;
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
    speed,
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
 * @param {{ apiKey: string, text: string, locale?: string, voiceStyle?: string, speechRate?: number }} opts
 */
async function synthesizeSpeech({
  apiKey,
  text,
  voice,
  speed,
  locale = 'pt',
  voiceStyle = VOICE_STYLES.gentleNanny,
  speechRate,
}) {
  const input = `${text || ''}`.trim();
  if (!input) {
    throw new Error('TTS input vazio.');
  }

  const loc = `${locale || 'pt'}`.trim();
  const style = VOICE_STYLES[voiceStyle] ? voiceStyle : VOICE_STYLES.gentleNanny;
  const resolvedSpeed = defaultSpeedForStyle(style, speechRate ?? speed);
  const instructions = instructionsForLocale(loc, style);
  const neuralVoice = voice || voiceForProfile(loc, style);

  // Neural com instruções primeiro (babá gentil); HD só como fallback.
  const attempts = [
    {
      model: 'gpt-4o-mini-tts',
      voice: neuralVoice,
      instructions,
      speed: resolvedSpeed,
    },
    {
      model: 'gpt-4o-mini-tts',
      voice: 'sage',
      instructions,
      speed: resolvedSpeed,
    },
    {
      model: 'tts-1-hd',
      voice: voiceForHdFallback(loc),
      instructions: null,
      speed: Math.min(1.0, resolvedSpeed + 0.02),
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
        speed: attempt.speed,
        instructions: attempt.instructions,
      });
    } catch (err) {
      lastErr = err;
      console.warn(
        `OpenAI TTS fallback: ${attempt.model}/${attempt.voice} style=${style}:`,
        err?.message || err,
      );
    }
  }

  throw lastErr || new Error('OpenAI TTS falhou.');
}

module.exports = {
  synthesizeSpeech,
  voiceForLocale: voiceForProfile,
  voiceForProfile,
  instructionsForLocale,
  VOICE_STYLES,
};
