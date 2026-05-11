/**
 * Cloud Functions — Foto da Semana
 *
 * Requer coleções `public_memories` e `weekly_photo_contests` com regras adequadas
 * (ver README nesta pasta).
 */
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');

/** Definir antes do deploy: `firebase functions:secrets:set FORCE_WEEKLY_DRAW_SECRET` */
const forceWeeklyDrawSecret = defineSecret('FORCE_WEEKLY_DRAW_SECRET');

admin.initializeApp();
const db = admin.firestore();

function pad2(n) {
  return `${n}`.padStart(2, '0');
}

/** Segunda-feira 00:00 local (relógio do servidor). */
function mondayStart(d) {
  const x = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const day = x.getDay(); // 0=Dom … 6=Sab
  const diff = day === 0 ? -6 : 1 - day;
  x.setDate(x.getDate() + diff);
  return x;
}

/** Chave da semana do sorteio (YYYY-MM-DD da segunda ISO). */
function contestWeekKey(d) {
  const m = mondayStart(d);
  return `${m.getFullYear()}-${pad2(m.getMonth() + 1)}-${pad2(m.getDate())}`;
}

/** Segunda seguinte (ex.: após sexta — fim da exibição na Home). */
function nextMondayAfter(d) {
  const m = mondayStart(d);
  const n = new Date(m.getTime());
  n.setDate(n.getDate() + 7);
  return n;
}

/** ISO string -> Date ou null. */
function parseIsoDate(s) {
  if (s == null || `${s}`.trim() === '') return null;
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d;
}

/**
 * Uma entrada por utilizador (`userId`): se várias memórias públicas na mesma semana,
 * fica a que ficou pública primeiro (`publicEnabledAt` mais antigo; empate: doc `id` menor).
 */
function oneCandidatePerUser(rows) {
  const bestByUser = new Map();
  for (const row of rows) {
    const uid = `${row.userId || ''}`.trim();
    if (!uid) continue;

    const prev = bestByUser.get(uid);
    if (!prev) {
      bestByUser.set(uid, row);
      continue;
    }

    const tNew = parseIsoDate(row.publicEnabledAt);
    const tPrev = parseIsoDate(prev.publicEnabledAt);
    let replace = false;
    if (tNew != null && (tPrev == null || tNew < tPrev)) {
      replace = true;
    } else if (tNew == null && tPrev == null && `${row.id}` < `${prev.id}`) {
      replace = true;
    } else if (tNew != null && tPrev != null && tNew.getTime() === tPrev.getTime() && `${row.id}` < `${prev.id}`) {
      replace = true;
    }
    if (replace) bestByUser.set(uid, row);
  }
  return Array.from(bestByUser.values());
}

/**
 * Sorteia para `submissionWeekId` == segunda ISO da semana de `now`.
 * Grava `spotlight_current` + `weekly_photo_contests/{weekKey}` — todos os clientes leem o mesmo doc.
 */
async function runWeeklyPhotoDraw(now) {
  const weekKey = contestWeekKey(now);
  const q = await db
    .collection('public_memories')
    .where('submissionWeekId', '==', weekKey)
    .get();

  const withPhoto = q.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((row) => row.photoUrl && `${row.photoUrl}`.trim().length > 0);

  const candidates = oneCandidatePerUser(withPhoto);
  const spotlightRef = db.collection('weekly_photo_contests').doc('spotlight_current');

  if (candidates.length === 0) {
    await spotlightRef.set({
      status: 'inactive',
      week_id: weekKey,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      winner_photo_url: admin.firestore.FieldValue.delete(),
      winner_badge_title: admin.firestore.FieldValue.delete(),
      winner_baby_sex: admin.firestore.FieldValue.delete(),
    });
    return {
      weekKey,
      candidateCount: 0,
      status: 'inactive',
      forced: false,
    };
  }

  const pick = candidates[Math.floor(Math.random() * candidates.length)];
  const displayUntil = nextMondayAfter(now);

  await spotlightRef.set({
    status: 'active',
    week_id: weekKey,
    draw_at: admin.firestore.Timestamp.fromDate(now),
    display_until: admin.firestore.Timestamp.fromDate(displayUntil),
    winner_public_memory_id: pick.id,
    winner_photo_url: pick.photoUrl,
    winner_badge_title: pick.badgeTitle || '',
    winner_baby_display_name: pick.babyDisplayName || null,
    winner_baby_sex: pick.babySex === 'M' || pick.babySex === 'F' ? pick.babySex : null,
    winner_baby_age_label: pick.babyAgeLabel || null,
    winner_public_description: pick.publicDescription || null,
    winner_memory_date: pick.createdAt || null,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.collection('weekly_photo_contests').doc(weekKey).set(
    {
      id: weekKey,
      weekId: weekKey,
      startsAt: admin.firestore.Timestamp.fromDate(mondayStart(now)),
      endsAt: admin.firestore.Timestamp.fromDate(displayUntil),
      drawAt: admin.firestore.Timestamp.fromDate(now),
      displayUntil: admin.firestore.Timestamp.fromDate(displayUntil),
      winnerMemoryId: pick.memoryId || pick.id,
      winnerUserId: pick.userId || null,
      winnerBabyId: pick.babyId || null,
      winnerBabySex: pick.babySex === 'M' || pick.babySex === 'F' ? pick.babySex : null,
      status: 'active',
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return {
    weekKey,
    candidateCount: candidates.length,
    status: 'active',
    winnerPublicMemoryId: pick.id,
    winnerUserId: pick.userId || null,
    forced: false,
  };
}

/**
 * Sexta-feira ~00:05 — mesmo algoritmo que o sorteio manual; semana = `contestWeekKey(agora)`.
 * Se já existir destaque **ativo** para esta mesma `week_id` (ex.: sorteio antecipado à mão), não volta a sortear.
 */
exports.scheduleWeeklyPhotoDraw = onSchedule(
  {
    schedule: '5 0 * * FRI',
    timeZone: 'America/Sao_Paulo',
    region: 'southamerica-east1',
  },
  async () => {
    const now = new Date();
    const weekKey = contestWeekKey(now);
    const snap = await db.collection('weekly_photo_contests').doc('spotlight_current').get();
    const cur = snap.data() || {};
    if (
      cur.week_id === weekKey &&
      cur.status === 'active' &&
      cur.draw_at != null
    ) {
      console.log(`scheduleWeeklyPhotoDraw: skip, já existe sorteio ativo para ${weekKey}`);
      return;
    }
    await runWeeklyPhotoDraw(now);
  },
);

/**
 * Força o sorteio da **semana corrente** (mesma `weekKey` que o cron usaria hoje).
 * Protegido por secret — não expor na app. Depois do primeiro uso, o cron de sexta continua a aplicar a regra habitual.
 *
 * GET/POST `Authorization: Bearer <FORCE_WEEKLY_DRAW_SECRET>` ou `?secret=`
 */
exports.forceWeeklyPhotoDraw = onRequest(
  {
    region: 'southamerica-east1',
    secrets: [forceWeeklyDrawSecret],
    cors: false,
    invoker: 'public',
  },
  async (req, res) => {
    if (req.method !== 'GET' && req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }
    const expected = forceWeeklyDrawSecret.value();
    const header = req.get('Authorization') || '';
    const bearer = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
    const q = `${req.query.secret || ''}`.trim();
    const token = bearer || q;
    if (!expected || token !== expected) {
      res.status(403).send('Forbidden');
      return;
    }
    try {
      const out = await runWeeklyPhotoDraw(new Date());
      out.forced = true;
      res.status(200).json(out);
    } catch (e) {
      console.error('forceWeeklyPhotoDraw', e);
      res.status(500).json({ error: `${e.message || e}` });
    }
  },
);

/** Segunda-feira ~00:10 — remove destaque da Home. */
exports.expireWeeklyPhoto = onSchedule(
  {
    schedule: '10 0 * * MON',
    timeZone: 'America/Sao_Paulo',
    region: 'southamerica-east1',
  },
  async () => {
    await db
      .collection('weekly_photo_contests')
      .doc('spotlight_current')
      .set(
        {
          status: 'expired',
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
  },
);
