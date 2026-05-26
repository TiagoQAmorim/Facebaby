const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { interpretTranscript, MAX_TRANSCRIPT_CHARS } = require('./interpretTranscript');

const openAiApiKey = defineSecret('OPENAI_API_KEY');

exports.processTextRecord = onCall(
  {
    region: 'southamerica-east1',
    secrets: [openAiApiKey],
    timeoutSeconds: 45,
    memory: '256MiB',
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Faça login para registrar pelo chat.');
    }

    const transcript = `${request.data?.transcript || request.data?.text || ''}`.trim();
    const babyName = `${request.data?.babyName || ''}`.trim().slice(0, 80);
    const locale = `${request.data?.locale || request.data?.language || 'pt'}`.trim();

    if (!transcript) {
      throw new HttpsError('invalid-argument', 'Texto ausente.');
    }
    if (transcript.length > MAX_TRANSCRIPT_CHARS) {
      throw new HttpsError('invalid-argument', 'Texto muito longo.');
    }

    const apiKey = openAiApiKey.value();
    if (!apiKey) {
      throw new HttpsError(
        'failed-precondition',
        'Serviço de interpretação indisponível no servidor.',
      );
    }

    const interpretation = await interpretTranscript({
      apiKey,
      transcript,
      babyName,
    });

    return {
      transcript,
      interpretation,
    };
  },
);
