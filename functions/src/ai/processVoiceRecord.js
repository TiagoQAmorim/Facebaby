const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { transcribeAudio } = require('./openAiWhisper');
const { MAX_TRANSCRIPT_CHARS } = require('./interpretTranscript');

const openAiApiKey = defineSecret('OPENAI_API_KEY');

const MAX_AUDIO_BASE64_CHARS = 400_000;

exports.processVoiceRecord = onCall(
  {
    region: 'southamerica-east1',
    secrets: [openAiApiKey],
    timeoutSeconds: 60,
    memory: '512MiB',
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Faça login para usar o registro por voz.');
    }

    const audioBase64 = `${request.data?.audioBase64 || ''}`.trim();
    const mimeType = `${request.data?.mimeType || 'audio/m4a'}`.trim();
    const babyName = `${request.data?.babyName || ''}`.trim().slice(0, 80);
    const locale = `${request.data?.locale || request.data?.language || 'pt'}`.trim();

    if (!audioBase64) {
      throw new HttpsError('invalid-argument', 'Áudio ausente.');
    }
    if (audioBase64.length > MAX_AUDIO_BASE64_CHARS) {
      throw new HttpsError(
        'invalid-argument',
        'Áudio muito longo. Grave no máximo 20 segundos.',
      );
    }

    let audioBuffer;
    try {
      audioBuffer = Buffer.from(audioBase64, 'base64');
    } catch (_) {
      throw new HttpsError('invalid-argument', 'Áudio inválido.');
    }
    if (!audioBuffer.length || audioBuffer.length > 300_000) {
      throw new HttpsError('invalid-argument', 'Áudio inválido ou muito grande.');
    }

    const apiKey = openAiApiKey.value();
    if (!apiKey) {
      throw new HttpsError(
        'failed-precondition',
        'Serviço de voz indisponível no servidor.',
      );
    }

    let transcript = '';
    try {
      transcript = await transcribeAudio({
        apiKey,
        audioBuffer,
        mimeType,
        fileName: mimeType.includes('webm') ? 'recording.webm' : 'recording.m4a',
        language: locale,
      });
    } catch (err) {
      console.error('processVoiceRecord Whisper error', err);
      throw new HttpsError(
        'internal',
        'Não consegui entender o áudio. Tente falar de novo, mais perto do microfone.',
      );
    }

    transcript = transcript.slice(0, MAX_TRANSCRIPT_CHARS);

    // Interpretação fica no app (paralelo com askAiNanny) — evita 2ª chamada GPT aqui.
    return {
      transcript,
      interpretation: {
        type: 'unknown',
        summary: transcript,
        feeding: null,
        sleep: null,
        diaper: null,
        weight: null,
        height: null,
        symptom: null,
        consultation: null,
        vaccine: null,
      },
    };
  },
);
