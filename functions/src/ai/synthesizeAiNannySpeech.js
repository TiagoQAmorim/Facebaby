const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { synthesizeSpeech } = require('./openAiSpeech');

const openAiApiKey = defineSecret('OPENAI_API_KEY');

const MAX_TEXT_CHARS = 1200;

exports.synthesizeAiNannySpeech = onCall(
  {
    region: 'southamerica-east1',
    secrets: [openAiApiKey],
    timeoutSeconds: 60,
    memory: '512MiB',
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Faça login para ouvir a resposta.');
    }

    const text = `${request.data?.text || ''}`.trim();
    const locale = `${request.data?.locale || request.data?.language || 'pt'}`.trim();

    if (!text) {
      throw new HttpsError('invalid-argument', 'Texto vazio.');
    }
    if (text.length > MAX_TEXT_CHARS) {
      throw new HttpsError('invalid-argument', 'Texto muito longo para áudio.');
    }

    const apiKey = openAiApiKey.value();
    if (!apiKey) {
      throw new HttpsError(
        'failed-precondition',
        'Voz neural indisponível no servidor.',
      );
    }

    try {
      const { buffer, mimeType, model, voice } = await synthesizeSpeech({
        apiKey,
        text,
        locale,
        speed: 1.0,
      });

      return {
        audioBase64: buffer.toString('base64'),
        mimeType,
        model,
        voice,
      };
    } catch (err) {
      console.error('synthesizeAiNannySpeech error', err);
      const raw = `${err?.message || err}`;
      if (raw.includes('insufficient_quota') || raw.includes('HTTP 429')) {
        throw new HttpsError(
          'resource-exhausted',
          'Voz neural temporariamente indisponível. Tente ouvir de novo mais tarde.',
        );
      }
      throw new HttpsError(
        'internal',
        'Não foi possível gerar o áudio agora.',
      );
    }
  },
);
