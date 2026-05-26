const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { FieldValue } = require('firebase-admin/firestore');
const { getFirestore } = require('firebase-admin/firestore');
const { DateTime } = require('luxon');
const { buildBabyContextBlock } = require('./babyContext');
const { fetchFamilyAiHistory } = require('./aiProfile');
const { chatCompletion, clampAiNannyAnswer } = require('./openAiClient');
const {
  buildInsightSystem,
  buildDailyUserPrompt,
  buildWeeklyUserPrompt,
} = require('./prompts/aiInsightPrompt');

const openAiApiKey = defineSecret('OPENAI_API_KEY');
const SP = 'America/Sao_Paulo';

function todayKey() {
  return DateTime.now().setZone(SP).toFormat('yyyyMMdd');
}

function weekKey() {
  const now = DateTime.now().setZone(SP);
  const monday = now.startOf('week');
  return monday.toFormat('yyyyMMdd');
}

async function resolveBabyId(db, uid, babyIdInput) {
  const trimmed = `${babyIdInput || ''}`.trim();
  if (trimmed) return trimmed;
  const snap = await db.collection('users').doc(uid).collection('babies').limit(1).get();
  if (snap.empty) return null;
  return snap.docs[0].id;
}

async function buildStatsBlock(db, uid, babyId, kind) {
  const events = await db
    .collection('users')
    .doc(uid)
    .collection('events')
    .where('baby_id', '==', babyId)
    .limit(60)
    .get();

  const rows = [];
  for (const doc of events.docs) {
    const d = doc.data();
    const t = d.event_time || d.eventTime || d.created_at;
    const when = t?.toDate?.() ?? (t ? new Date(t) : null);
    if (!when || Number.isNaN(when.getTime())) continue;
    rows.push({ type: `${d.type || ''}`, when });
  }
  rows.sort((a, b) => b.when - a.when);

  const now = DateTime.now().setZone(SP).startOf('day');
  const dayKeys = new Set();
  for (let i = 0; i < 14; i++) {
    dayKeys.add(now.minus({ days: i }).toFormat('yyyy-MM-dd'));
  }

  const byDay = {};
  for (const r of rows) {
    const key = DateTime.fromJSDate(r.when, { zone: SP }).toFormat('yyyy-MM-dd');
    if (!dayKeys.has(key)) continue;
    byDay[key] ??= { sleep: 0, feeding: 0, diaper: 0 };
    if (r.type === 'sleep') byDay[key].sleep++;
    if (r.type === 'feeding') byDay[key].feeding++;
    if (r.type === 'diaper') byDay[key].diaper++;
  }

  const lines = Object.entries(byDay)
    .sort((a, b) => b[0].localeCompare(a[0]))
    .slice(0, kind === 'weekly' ? 14 : 4)
    .map(([day, v]) => `${day}: sono ${v.sleep}, mamadas ${v.feeding}, fraldas ${v.diaper}`);

  return lines.length
    ? lines.join('\n')
    : 'Poucos registros recentes no app.';
}

exports.ensureAiInsight = onCall(
  {
    region: 'southamerica-east1',
    secrets: [openAiApiKey],
    timeoutSeconds: 60,
    memory: '512MiB',
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Faça login.');
    }

    const uid = request.auth.uid;
    const kind = `${request.data?.kind || 'daily'}`.trim().toLowerCase();
    const periodKey = `${request.data?.periodKey || ''}`.trim();
    const locale = `${request.data?.locale || request.data?.language || 'pt'}`.trim();
    const babyIdInput = request.data?.babyId;

    const isWeekly = kind === 'weekly';
    const key = periodKey || (isWeekly ? weekKey() : todayKey());

    const db = getFirestore();
    const coll = isWeekly ? 'weekly' : 'daily';
    const ref = db.collection('ai_insights').doc(uid).collection(coll).doc(key);

    const existing = await ref.get();
    if (existing.exists) {
      const src = `${existing.data()?.source || ''}`.trim().toLowerCase();
      if (src === 'openai' && `${existing.data()?.text || ''}`.trim()) {
        return {
          cached: true,
          text: `${existing.data().text}`.trim(),
          source: 'openai',
          periodKey: key,
        };
      }
    }

    const userSnap = await db.collection('users').doc(uid).get();
    const user = userSnap.data() || {};
    if (user.premiumLifetime !== true) {
      throw new HttpsError(
        'permission-denied',
        'Insights com IA disponíveis no Premium.',
      );
    }

    const resolvedBabyId = await resolveBabyId(db, uid, babyIdInput);
    let contextBlock = 'Bebê não cadastrado.';
    if (resolvedBabyId) {
      try {
        const ctx = await buildBabyContextBlock(db, uid, resolvedBabyId);
        contextBlock = ctx.block;
      } catch (e) {
        console.warn('ensureAiInsight context', e);
      }
    }

    let familyHistoryBlock = '';
    try {
      familyHistoryBlock = await fetchFamilyAiHistory(db, uid);
    } catch (_) {}

    const statsBlock = resolvedBabyId
      ? await buildStatsBlock(db, uid, resolvedBabyId, kind)
      : 'Sem estatísticas.';

    const userPrompt = isWeekly
      ? buildWeeklyUserPrompt({ contextBlock, statsBlock, familyHistoryBlock })
      : buildDailyUserPrompt({ contextBlock, statsBlock, familyHistoryBlock });

    const apiKey = openAiApiKey.value();
    if (!apiKey) {
      throw new HttpsError('failed-precondition', 'OpenAI não configurada.');
    }

    const completion = await chatCompletion({
      apiKey,
      system: buildInsightSystem(locale),
      user: userPrompt,
      maxTokens: 80,
      temperature: 0.45,
    });

    let text = clampAiNannyAnswer(`${completion.text || ''}`.trim(), 200);
    if (!text) {
      throw new HttpsError('internal', 'Insight vazio.');
    }

    await ref.set(
      {
        text,
        babyId: resolvedBabyId || null,
        type: isWeekly ? 'weekly' : 'daily',
        source: 'openai',
        locale,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: existing.exists
          ? existing.data()?.createdAt || FieldValue.serverTimestamp()
          : FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return {
      cached: false,
      text,
      source: 'openai',
      periodKey: key,
    };
  },
);
