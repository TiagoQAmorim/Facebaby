const { FieldValue } = require('firebase-admin/firestore');
const { DateTime } = require('luxon');

const SP = 'America/Sao_Paulo';
const DAILY_MESSAGE_LIMIT = 50;

function todayKey() {
  return DateTime.now().setZone(SP).toFormat('yyyyMMdd');
}

function dailyUsageRef(db, uid, dateKey = todayKey()) {
  return db.collection('ai_usage').doc(uid).collection('daily').doc(dateKey);
}

async function getUsageCount(db, uid) {
  const snap = await dailyUsageRef(db, uid).get();
  if (!snap.exists) return 0;
  const data = snap.data() || {};
  return Number(data.count ?? data.messageCount ?? 0) || 0;
}

async function assertCanSend(db, uid) {
  const count = await getUsageCount(db, uid);
  if (count >= DAILY_MESSAGE_LIMIT) {
    const err = new Error('DAILY_LIMIT');
    err.code = 'resource-exhausted';
    throw err;
  }
  return { count, remaining: Math.max(0, DAILY_MESSAGE_LIMIT - count - 1) };
}

async function recordUsage(db, uid) {
  const ref = dailyUsageRef(db, uid);
  await ref.set(
    {
      count: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

module.exports = {
  DAILY_MESSAGE_LIMIT,
  dailyUsageRef,
  getUsageCount,
  assertCanSend,
  recordUsage,
  todayKey,
};
