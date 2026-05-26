const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { chatCompletion } = require('./openAiClient');
const {
  PARSE_AI_NANNY_SYSTEM,
  buildParseAiNannyUserPrompt,
  parseAiNannyMessageJson,
  nowSpIso,
} = require('./prompts/parseAiNannyMessagePrompt');

const openAiApiKey = defineSecret('OPENAI_API_KEY');
const MAX_MESSAGE_CHARS = 500;

exports.parseAiNannyMessage = onCall(
  {
    region: 'southamerica-east1',
    secrets: [openAiApiKey],
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Faça login para registrar.');
    }

    const message = `${request.data?.message || ''}`.trim().slice(0, MAX_MESSAGE_CHARS);
    if (!message) {
      return {
        classification: 'chat_only',
        records: [],
        needsConfirmation: false,
      };
    }

    const apiKey = openAiApiKey.value();
    if (!apiKey) {
      throw new HttpsError('failed-precondition', 'OPENAI_API_KEY não configurada.');
    }

    const babyName = `${request.data?.babyName || ''}`.trim().slice(0, 80);
    const locale = `${request.data?.locale || 'pt_BR'}`.trim();
    const timezone = `${request.data?.timezone || 'America/Sao_Paulo'}`.trim();
    const nowIso = `${request.data?.nowIso || nowSpIso()}`.trim();
    const lastWeightKg = request.data?.lastWeightKg;
    const lastHeightCm = request.data?.lastHeightCm;

    try {
      const completion = await chatCompletion({
        apiKey,
        system: PARSE_AI_NANNY_SYSTEM,
        user: buildParseAiNannyUserPrompt({
          message,
          babyName,
          nowIso,
          timezone,
          locale,
          lastWeightKg:
            typeof lastWeightKg === 'number' ? lastWeightKg : undefined,
          lastHeightCm:
            typeof lastHeightCm === 'number' ? lastHeightCm : undefined,
        }),
        maxTokens: 420,
        temperature: 0.2,
      });

      const parsed = parseAiNannyMessageJson(completion.text);
      if (parsed.records.length > 0) {
        parsed.classification = 'create_records';
        parsed.needsConfirmation = true;
      }
      return parsed;
    } catch (err) {
      console.error('parseAiNannyMessage', err);
      throw new HttpsError(
        'internal',
        'Não consegui interpretar a mensagem. Tente novamente.',
      );
    }
  },
);
