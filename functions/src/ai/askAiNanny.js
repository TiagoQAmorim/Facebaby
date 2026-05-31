const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { FieldValue } = require('firebase-admin/firestore');
const { getFirestore } = require('firebase-admin/firestore');
const { buildBabyContextBlock } = require('./babyContext');
const { fetchFamilyAiHistory } = require('./aiProfile');
const { buildAiNannySystem, buildAiNannyUserPrompt } = require('./prompts/aiNannyPrompt');
const { chatCompletion, clampAiNannyAnswer } = require('./openAiClient');
const {
  DAILY_MESSAGE_LIMIT,
  assertCanSend,
  recordUsage,
  getUsageCount,
} = require('./aiUsageLimiter');
const { trimAiChatHistory } = require('./aiChatRetention');
const {
  classifyAiNannyQuestion,
  offTopicRefusalMessage,
} = require('./aiNannyTopicGuard');

const openAiApiKey = defineSecret('OPENAI_API_KEY');

const DAILY_LIMIT_MSG =
  'Você atingiu o limite diário da IA Babá. Volte amanhã.';

const OPENAI_QUOTA_MSG =
  'A IA Babá está temporariamente indisponível (cota OpenAI esgotada). ' +
  'Adicione créditos em platform.openai.com e tente de novo.';

const OPENAI_AUTH_MSG =
  'Chave OpenAI inválida no servidor. Peça suporte para reconfigurar OPENAI_API_KEY.';

/** Mapeia erro da OpenAI para HttpsError com mensagem útil no app. */
function mapOpenAiError(err) {
  const raw = `${err?.message || err || ''}`;
  if (raw.includes('insufficient_quota') || raw.includes('OpenAI HTTP 429')) {
    return new HttpsError('failed-precondition', OPENAI_QUOTA_MSG);
  }
  if (raw.includes('OpenAI HTTP 401') || raw.includes('invalid_api_key')) {
    return new HttpsError('failed-precondition', OPENAI_AUTH_MSG);
  }
  if (raw.includes('OPENAI_API_KEY não configurada')) {
    return new HttpsError('failed-precondition', OPENAI_AUTH_MSG);
  }
  return new HttpsError(
    'internal',
    'Não consegui responder agora. Tente novamente em alguns instantes.',
  );
}

async function resolveBabyId(db, uid, babyId) {
  const trimmed = `${babyId || ''}`.trim();
  if (trimmed) return trimmed;
  const snap = await db
    .collection('users')
    .doc(uid)
    .collection('babies')
    .limit(1)
    .get();
  if (snap.empty) return null;
  return snap.docs[0].id;
}

const CHAT_HISTORY_TURNS = 4;
const MAX_HISTORY_CHARS = 280;

/** Últimas perguntas/respostas para o modelo não repetir o mesmo texto. */
async function loadRecentChatHistory(db, uid) {
  try {
    const snap = await db
      .collection('ai_chats')
      .doc(uid)
      .collection('messages')
      .orderBy('createdAt', 'desc')
      .limit(CHAT_HISTORY_TURNS)
      .get();

    const pairs = [];
    for (const doc of snap.docs) {
      const d = doc.data();
      if (`${d.status || ''}` !== 'sent') continue;
      const q = `${d.question || ''}`.trim();
      const a = `${d.answer || ''}`.trim();
      if (!q || !a) continue;
      pairs.push({ q, a });
    }
    pairs.reverse();

    const messages = [];
    for (const { q, a } of pairs) {
      const qShort =
        q.length > MAX_HISTORY_CHARS ? `${q.slice(0, MAX_HISTORY_CHARS)}…` : q;
      const aShort =
        a.length > MAX_HISTORY_CHARS ? `${a.slice(0, MAX_HISTORY_CHARS)}…` : a;
      messages.push({ role: 'user', content: qShort });
      messages.push({ role: 'assistant', content: aShort });
    }
    return messages;
  } catch (err) {
    console.warn('askAiNanny loadRecentChatHistory', err);
    return [];
  }
}

async function saveChatMessage(db, uid, payload) {
  const ref = db
    .collection('ai_chats')
    .doc(uid)
    .collection('messages')
    .doc();
  await ref.set({
    ...payload,
    createdAt: FieldValue.serverTimestamp(),
  });
  return ref.id;
}

exports.askAiNanny = onCall(
  {
    region: 'southamerica-east1',
    secrets: [openAiApiKey],
    timeoutSeconds: 120,
    memory: '512MiB',
  },
  async (request) => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'Faça login para usar a IA Babá.');
      }

      const uid = request.auth.uid;
      const question = `${request.data?.question || ''}`.trim();
      const agentHint = `${request.data?.agentHint || ''}`.trim();
      const growthCurveContext = `${request.data?.growthCurveContext || ''}`.trim();
      const babyIdInput = request.data?.babyId;
      const locale = `${request.data?.locale || request.data?.language || 'pt'}`.trim();

      if (!question) {
        throw new HttpsError('invalid-argument', 'Pergunta vazia.');
      }
      if (question.length > 2000) {
        throw new HttpsError('invalid-argument', 'Pergunta muito longa.');
      }
      if (agentHint.length > 1500) {
        throw new HttpsError('invalid-argument', 'Instrução interna muito longa.');
      }
      if (growthCurveContext.length > 2500) {
        throw new HttpsError('invalid-argument', 'Contexto de crescimento muito longo.');
      }

      const db = getFirestore();

      const topicClass = classifyAiNannyQuestion(question);
      if (topicClass === 'off_topic') {
        const refusal = offTopicRefusalMessage(locale);
        const messageId = await saveChatMessage(db, uid, {
          babyId: null,
          question,
          answer: refusal,
          status: 'sent',
          source: 'guard',
          errorMessage: null,
        });
        const count = await getUsageCount(db, uid);
        return {
          answer: refusal,
          messageId,
          babyId: null,
          remainingToday: Math.max(0, DAILY_MESSAGE_LIMIT - count),
          dailyLimit: DAILY_MESSAGE_LIMIT,
        };
      }

      try {
        await assertCanSend(db, uid);
      } catch (e) {
        if (e.code === 'resource-exhausted' || e.message === 'DAILY_LIMIT') {
          throw new HttpsError('resource-exhausted', DAILY_LIMIT_MSG);
        }
        throw e;
      }

      const resolvedBabyId = await resolveBabyId(db, uid, babyIdInput);

      const defaultContextBlock =
        'Nenhum bebê cadastrado ou selecionado. Responda de forma geral e acolhedora; peça mais detalhes se necessário.';

      const [contextBlockRaw, familyHistoryBlock, historyMessages] = await Promise.all([
        resolvedBabyId
          ? buildBabyContextBlock(db, uid, resolvedBabyId)
              .then((ctx) => ctx.block)
              .catch((ctxErr) => {
                console.warn('askAiNanny babyContext warning', ctxErr);
                return defaultContextBlock;
              })
          : Promise.resolve(defaultContextBlock),
        fetchFamilyAiHistory(db, uid).catch((histErr) => {
          console.warn('askAiNanny ai_profiles warning', histErr);
          return '';
        }),
        loadRecentChatHistory(db, uid),
      ]);

      const contextBlock = growthCurveContext
        ? `${contextBlockRaw}\n\n${growthCurveContext}`
        : contextBlockRaw;

      if (familyHistoryBlock) {
        console.log(
          'askAiNanny ai_profiles promptChars=',
          familyHistoryBlock.length,
        );
      }

      const userPrompt = buildAiNannyUserPrompt({
        question,
        agentHint,
        contextBlock,
        familyHistoryBlock,
        conversationInProgress: historyMessages.length > 0,
      });
      let answer = '';
      let status = 'sent';
      let errorMessage = null;
      let source = 'openai';

      try {
        const apiKey = openAiApiKey.value();
        if (!apiKey) {
          throw new Error('OPENAI_API_KEY não configurada.');
        }
        const completion = await chatCompletion({
          apiKey,
          system: buildAiNannySystem(locale),
          user: userPrompt,
          historyMessages,
          maxTokens: 200,
          temperature: 0.42,
        });
        answer = clampAiNannyAnswer(`${completion.text || ''}`.trim());
        if (!answer) {
          throw new Error('Resposta vazia da OpenAI.');
        }
        await recordUsage(db, uid);
      } catch (err) {
        console.error('askAiNanny OpenAI error', err);
        status = 'failed';
        errorMessage = `${err.message || err}`.slice(0, 500);
        answer = '';
        source = 'openai';
        await saveChatMessage(db, uid, {
          babyId: resolvedBabyId || null,
          question,
          answer: '',
          status,
          source,
          errorMessage,
        });
        throw mapOpenAiError(err);
      }

      const messageId = await saveChatMessage(db, uid, {
        babyId: resolvedBabyId || null,
        question,
        answer,
        status,
        source,
        errorMessage,
      });

      try {
        await trimAiChatHistory(db, uid);
      } catch (trimErr) {
        console.warn('askAiNanny trimAiChatHistory', trimErr);
      }

      const count = await getUsageCount(db, uid);

      return {
        answer,
        messageId,
        babyId: resolvedBabyId || null,
        remainingToday: Math.max(0, DAILY_MESSAGE_LIMIT - count),
        dailyLimit: DAILY_MESSAGE_LIMIT,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('askAiNanny unexpected error', err);
      throw new HttpsError(
        'internal',
        'Não consegui responder agora. Tente novamente em alguns instantes.',
      );
    }
  },
);
