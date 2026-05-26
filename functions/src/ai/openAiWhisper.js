/**
 * OpenAI Whisper — transcrição server-side.
 * @param {{ apiKey: string, audioBuffer: Buffer, mimeType?: string, fileName?: string }} opts
 */
const WHISPER_LANG = new Set(['pt', 'en', 'es', 'fr', 'de', 'it', 'hi', 'id', 'ja', 'ko', 'ru', 'tr', 'zh']);

function normalizeWhisperLanguage(locale) {
  const code = `${locale || 'pt'}`.trim().toLowerCase().split(/[-_]/)[0];
  return WHISPER_LANG.has(code) ? code : 'en';
}

async function transcribeAudio({
  apiKey,
  audioBuffer,
  mimeType = 'audio/m4a',
  fileName = 'recording.m4a',
  language = 'pt',
}) {
  const form = new FormData();
  const blob = new Blob([audioBuffer], { type: mimeType });
  form.append('file', blob, fileName);
  form.append('model', 'whisper-1');
  form.append('language', normalizeWhisperLanguage(language));

  const res = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}` },
    body: form,
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Whisper HTTP ${res.status}: ${errText.slice(0, 400)}`);
  }

  const json = await res.json();
  const text = `${json?.text || ''}`.trim();
  if (!text) throw new Error('Whisper returned empty transcript');
  return text;
}

module.exports = { transcribeAudio, normalizeWhisperLanguage };
