const { FieldValue } = require('firebase-admin/firestore');
const { DateTime } = require('luxon');

const SP = 'America/Sao_Paulo';

/** Chaves estáveis para agregação no admin. */
const AI_FEATURES = {
  ASK_AI_NANNY: 'ask_ai_nanny',
  PARSE_AI_NANNY: 'parse_ai_nanny',
  ENSURE_AI_INSIGHT: 'ensure_ai_insight',
  FAMILY_HOMILY: 'family_homily',
  FAMILY_HOROSCOPE_SIGN: 'family_horoscope_sign',
  FAMILY_HOROSCOPE_COMPAT: 'family_horoscope_compat',
  WARM_HOMILY: 'warm_homily',
  WARM_HOROSCOPE_SIGN: 'warm_horoscope_sign',
  INTERPRET_TRANSCRIPT: 'interpret_transcript',
  WHISPER_TRANSCRIBE: 'whisper_transcribe',
};

function todayKey(date = new Date()) {
  return DateTime.fromJSDate(date, { zone: 'utc' })
    .setZone(SP)
    .toFormat('yyyyMMdd');
}

function monthKey(date = new Date()) {
  return DateTime.fromJSDate(date, { zone: 'utc' })
    .setZone(SP)
    .toFormat('yyyyMM');
}

function normalizeUsage(usage) {
  const prompt = Number(usage?.prompt_tokens ?? usage?.promptTokens ?? 0) || 0;
  const completion =
    Number(usage?.completion_tokens ?? usage?.completionTokens ?? 0) || 0;
  let total = Number(usage?.total_tokens ?? usage?.totalTokens ?? 0) || 0;
  if (total <= 0 && (prompt > 0 || completion > 0)) {
    total = prompt + completion;
  }
  return { prompt, completion, total };
}

function globalDayRef(db, dateKey) {
  return db.collection('ai_usage_global').doc('daily').collection('days').doc(dateKey);
}

function userDayRef(db, uid, dateKey) {
  return db
    .collection('ai_usage')
    .doc(uid)
    .collection('daily')
    .doc(dateKey);
}

function userMonthRef(db, uid, month) {
  return db
    .collection('ai_usage')
    .doc(uid)
    .collection('monthly')
    .doc(month);
}

function activeUserRef(db, dateKey, uid) {
  return globalDayRef(db, dateKey).collection('users').doc(uid);
}

/**
 * Regista tokens/calls por ferramenta (global + utilizador quando [uid] presente).
 * Falhas de telemetria nunca devem quebrar a feature principal.
 */
async function recordAiUsage(db, {
  uid = null,
  feature,
  model = null,
  usage = null,
  whisperSeconds = 0,
}) {
  if (!db || !feature) return;

  const { prompt, completion, total } = normalizeUsage(usage);
  const whisperSec = Number(whisperSeconds) || 0;
  const dateKey = todayKey();
  const month = monthKey();
  const now = FieldValue.serverTimestamp();

  const featurePatch = {
    [`byFeature.${feature}.calls`]: FieldValue.increment(1),
    [`byFeature.${feature}.promptTokens`]: FieldValue.increment(prompt),
    [`byFeature.${feature}.completionTokens`]: FieldValue.increment(completion),
    [`byFeature.${feature}.totalTokens`]: FieldValue.increment(total),
    totalCalls: FieldValue.increment(1),
    totalPromptTokens: FieldValue.increment(prompt),
    totalCompletionTokens: FieldValue.increment(completion),
    totalTokens: FieldValue.increment(total),
    updatedAt: now,
  };
  if (model) featurePatch.lastModel = model;
  if (whisperSec > 0) {
    featurePatch[`byFeature.${feature}.whisperSeconds`] =
      FieldValue.increment(whisperSec);
    featurePatch.totalWhisperSeconds = FieldValue.increment(whisperSec);
  }

  try {
    await globalDayRef(db, dateKey).set(featurePatch, { merge: true });
  } catch (e) {
    console.warn('recordAiUsage global', feature, e);
  }

  if (!uid) return;

  const userPatch = {
    [`byFeature.${feature}.calls`]: FieldValue.increment(1),
    [`byFeature.${feature}.promptTokens`]: FieldValue.increment(prompt),
    [`byFeature.${feature}.completionTokens`]: FieldValue.increment(completion),
    [`byFeature.${feature}.totalTokens`]: FieldValue.increment(total),
    totalCalls: FieldValue.increment(1),
    totalPromptTokens: FieldValue.increment(prompt),
    totalCompletionTokens: FieldValue.increment(completion),
    totalTokens: FieldValue.increment(total),
    updatedAt: now,
  };
  if (whisperSec > 0) {
    userPatch[`byFeature.${feature}.whisperSeconds`] =
      FieldValue.increment(whisperSec);
    userPatch.totalWhisperSeconds = FieldValue.increment(whisperSec);
  }

  try {
    await userDayRef(db, uid, dateKey).set(userPatch, { merge: true });
    await userMonthRef(db, uid, month).set(userPatch, { merge: true });
    await activeUserRef(db, dateKey, uid).set(
      {
        totalCalls: FieldValue.increment(1),
        totalTokens: FieldValue.increment(total),
        totalPromptTokens: FieldValue.increment(prompt),
        totalCompletionTokens: FieldValue.increment(completion),
        [`byFeature.${feature}.totalTokens`]: FieldValue.increment(total),
        [`byFeature.${feature}.calls`]: FieldValue.increment(1),
        updatedAt: now,
      },
      { merge: true },
    );
  } catch (e) {
    console.warn('recordAiUsage user', uid, feature, e);
  }
}

/** Whisper cobra por duração — estimamos tokens equivalentes p/ ranking (~25/s). */
function estimateWhisperTokenEquivalent(audioBytes) {
  const bytes = Number(audioBytes) || 0;
  const seconds = Math.max(1, Math.ceil(bytes / 8000));
  return { seconds, tokenEquivalent: seconds * 25 };
}

module.exports = {
  AI_FEATURES,
  todayKey,
  monthKey,
  normalizeUsage,
  recordAiUsage,
  estimateWhisperTokenEquivalent,
  globalDayRef,
  activeUserRef,
  userDayRef,
};
