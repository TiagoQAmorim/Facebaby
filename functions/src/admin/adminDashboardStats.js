const { HttpsError } = require('firebase-functions/v2/https');
const { DateTime } = require('luxon');
const { todayKey, globalDayRef } = require('../ai/aiUsageTelemetry');

const SP = 'America/Sao_Paulo';

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

async function safeCount(query) {
  try {
    const snap = await query.count().get();
    return snap.data().count ?? 0;
  } catch (e) {
    console.warn('adminDashboardStats count failed', e);
    return null;
  }
}

function createAdminGetDashboardStats({ onCall, db }) {
  return onCall({ region: 'southamerica-east1' }, async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Sign in required');
    }
    await assertPanelAdmin(db, request.auth.uid);

    const nowSp = DateTime.now().setZone(SP);
    const weekAgo = nowSp.minus({ days: 7 }).toJSDate();

    const usersCol = db.collection('users');
    const [
      totalUsers,
      premiumUsers,
      suspendedUsers,
      publicMemories,
      aiDaySnap,
      aiActiveUsers,
    ] = await Promise.all([
      safeCount(usersCol),
      safeCount(usersCol.where('premiumLifetime', '==', true)),
      safeCount(usersCol.where('status', '==', 'suspended')),
      safeCount(db.collection('public_memories')),
      globalDayRef(db, todayKey()).get(),
      safeCount(
        globalDayRef(db, todayKey()).collection('users'),
      ),
    ]);

    let newUsersThisWeek = null;
    try {
      newUsersThisWeek = await safeCount(
        usersCol.where('createdAt', '>=', weekAgo),
      );
    } catch (e) {
      console.warn('adminDashboardStats newUsers week', e);
    }

    const aiDay = aiDaySnap.data() || {};
    const spotlight = await db
      .collection('weekly_photo_contests')
      .doc('spotlight_current')
      .get();
    const winnerName = spotlight.exists
      ? `${spotlight.data()?.winner_baby_display_name ||
          spotlight.data()?.winnerBabyDisplayName ||
          '—'}`
      : '—';

    return {
      totalUsers: totalUsers ?? 0,
      premiumUsers: premiumUsers ?? 0,
      freeUsers: Math.max(0, (totalUsers ?? 0) - (premiumUsers ?? 0)),
      suspendedUsers: suspendedUsers ?? 0,
      activeUsers: Math.max(0, (totalUsers ?? 0) - (suspendedUsers ?? 0)),
      newUsersThisWeek: newUsersThisWeek ?? 0,
      totalPublicMemories: publicMemories ?? 0,
      aiNannyUsers: aiActiveUsers ?? 0,
      aiCallsToday: Number(aiDay.totalCalls ?? 0) || 0,
      aiTokensToday: Number(aiDay.totalTokens ?? 0) || 0,
      weeklyWinnerName: winnerName,
      generatedAt: nowSp.toISO(),
    };
  });
}

module.exports = { createAdminGetDashboardStats };
