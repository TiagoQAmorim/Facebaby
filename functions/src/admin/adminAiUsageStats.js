const { HttpsError } = require('firebase-functions/v2/https');
const { todayKey, globalDayRef } = require('../ai/aiUsageTelemetry');

const FEATURE_LABELS = {
  ask_ai_nanny: 'Chat IA Babá',
  parse_ai_nanny: 'Parser registos IA',
  ensure_ai_insight: 'Insight diário/semanal',
  family_homily: 'Homilia familiar',
  family_horoscope_sign: 'Horóscopo (signo)',
  family_horoscope_compat: 'Horóscopo (compat.)',
  warm_homily: 'Cron homilia 7h30',
  warm_horoscope_sign: 'Cron horóscopo 7h30',
  interpret_transcript: 'Interpretar texto',
  whisper_transcribe: 'Whisper (voz)',
};

async function assertPanelAdmin(db, uid) {
  const doc = await db.collection('admins').doc(uid).get();
  if (!doc.exists) throw new HttpsError('permission-denied', 'Not an admin');
  const d = doc.data() || {};
  if (d.active !== true) {
    throw new HttpsError('permission-denied', 'Admin inactive');
  }
  const role = `${d.role || ''}`.trim().toLowerCase();
  if (role !== 'owner' && role !== 'admin') {
    throw new HttpsError('permission-denied', 'Insufficient role');
  }
}

function serializeFeatureRows(byFeature) {
  const raw = byFeature && typeof byFeature === 'object' ? byFeature : {};
  const rows = Object.entries(raw).map(([feature, stats]) => {
    const s = stats && typeof stats === 'object' ? stats : {};
    return {
      feature,
      label: FEATURE_LABELS[feature] || feature,
      calls: Number(s.calls ?? 0) || 0,
      totalTokens: Number(s.totalTokens ?? 0) || 0,
      promptTokens: Number(s.promptTokens ?? 0) || 0,
      completionTokens: Number(s.completionTokens ?? 0) || 0,
      whisperSeconds: Number(s.whisperSeconds ?? 0) || 0,
    };
  });
  rows.sort((a, b) => b.totalTokens - a.totalTokens);
  return rows;
}

function createAdminGetAiUsageStats({ onCall, db }) {
  return onCall({ region: 'southamerica-east1' }, async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Sign in required');
    }
    await assertPanelAdmin(db, request.auth.uid);

    const dateKey = `${request.data?.dateKey || ''}`.trim() || todayKey();
    const topLimit = Math.min(
      Math.max(Number(request.data?.topLimit ?? 50) || 50, 1),
      100,
    );

    const daySnap = await globalDayRef(db, dateKey).get();
    const day = daySnap.data() || {};

    const usersSnap = await globalDayRef(db, dateKey)
      .collection('users')
      .orderBy('totalTokens', 'desc')
      .limit(topLimit)
      .get();

    const uids = usersSnap.docs.map((d) => d.id);
    const profiles = new Map();
    for (let i = 0; i < uids.length; i += 10) {
      const chunk = uids.slice(i, i + 10);
      const refs = chunk.map((uid) => db.collection('users').doc(uid));
      const snaps = await db.getAll(...refs);
      for (const snap of snaps) {
        if (!snap.exists) continue;
        const d = snap.data() || {};
        profiles.set(snap.id, {
          email: `${d.email || ''}`.trim(),
          name: `${d.name || d.displayName || ''}`.trim(),
        });
      }
    }

    const topUsers = usersSnap.docs.map((doc, index) => {
      const d = doc.data() || {};
      const profile = profiles.get(doc.id) || {};
      const byFeature = d.byFeature || {};
      let topFeature = '';
      let topFeatureTokens = 0;
      for (const [feature, stats] of Object.entries(byFeature)) {
        const t = Number(stats?.totalTokens ?? 0) || 0;
        if (t > topFeatureTokens) {
          topFeatureTokens = t;
          topFeature = feature;
        }
      }
      return {
        rank: index + 1,
        uid: doc.id,
        email: profile.email || '',
        name: profile.name || '—',
        totalCalls: Number(d.totalCalls ?? 0) || 0,
        totalTokens: Number(d.totalTokens ?? 0) || 0,
        topFeature,
        topFeatureLabel: FEATURE_LABELS[topFeature] || topFeature || '—',
      };
    });

    return {
      dateKey,
      summary: {
        totalCalls: Number(day.totalCalls ?? 0) || 0,
        totalTokens: Number(day.totalTokens ?? 0) || 0,
        totalPromptTokens: Number(day.totalPromptTokens ?? 0) || 0,
        totalCompletionTokens: Number(day.totalCompletionTokens ?? 0) || 0,
        totalWhisperSeconds: Number(day.totalWhisperSeconds ?? 0) || 0,
        activeUsers: usersSnap.size,
      },
      byFeature: serializeFeatureRows(day.byFeature),
      topUsers,
    };
  });
}

function createAdminGetUserAiUsage({ onCall, db }) {
  return onCall({ region: 'southamerica-east1' }, async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Sign in required');
    }
    await assertPanelAdmin(db, request.auth.uid);

    const uid = `${request.data?.uid || ''}`.trim();
    if (!uid) throw new HttpsError('invalid-argument', 'uid required');

    const dateKey = `${request.data?.dateKey || ''}`.trim() || todayKey();
    const daySnap = await db
      .collection('ai_usage')
      .doc(uid)
      .collection('daily')
      .doc(dateKey)
      .get();
    const monthSnap = await db
      .collection('ai_usage')
      .doc(uid)
      .collection('monthly')
      .doc(dateKey.slice(0, 6))
      .get();

    const day = daySnap.data() || {};
    const month = monthSnap.data() || {};

    return {
      uid,
      dateKey,
      today: {
        totalCalls: Number(day.totalCalls ?? day.count ?? 0) || 0,
        totalTokens: Number(day.totalTokens ?? 0) || 0,
        byFeature: serializeFeatureRows(day.byFeature),
      },
      month: {
        monthKey: dateKey.slice(0, 6),
        totalCalls: Number(month.totalCalls ?? 0) || 0,
        totalTokens: Number(month.totalTokens ?? 0) || 0,
        byFeature: serializeFeatureRows(month.byFeature),
      },
    };
  });
}

module.exports = {
  createAdminGetAiUsageStats,
  createAdminGetUserAiUsage,
  FEATURE_LABELS,
};
