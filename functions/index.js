/**
 * Cloud Functions — Foto da Semana
 *
 * Requer coleções `public_memories` e `weekly_photo_contests` com regras adequadas
 * (ver README nesta pasta).
 *
 * Todas as datas de concurso / exibição usam o fuso **America/Sao_Paulo** (não o UTC do
 * runtime do Node), para o sorteio de domingo 23:58 coincidir com o calendário brasileiro.
 */
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const { DateTime } = require('luxon');

/** Secret para [forceWeeklyPhotoDraw] — `firebase functions:secrets:set FORCE_WEEKLY_DRAW_SECRET` */
const forceWeeklyDrawSecret = defineSecret('FORCE_WEEKLY_DRAW_SECRET');

/** OpenAI — `firebase functions:secrets:set OPENAI_API_KEY` */
const openAiApiKey = defineSecret('OPENAI_API_KEY');

const { askAiNanny } = require('./src/ai/askAiNanny');
const {
  createAdminBroadcastHandlers,
} = require('./src/admin/adminBroadcast');
const { synthesizeAiNannySpeech } = require('./src/ai/synthesizeAiNannySpeech');
const { processVoiceRecord } = require('./src/ai/processVoiceRecord');
const { processTextRecord } = require('./src/ai/processTextRecord');
const { parseAiNannyMessage } = require('./src/ai/parseAiNannyMessage');
const { manageAiNannyChat } = require('./src/ai/manageAiNannyChat');
const { createGenerateDailyFamilyHoroscope } = require('./src/ai/generateDailyFamilyHoroscope');
const { ensureAiInsight } = require('./src/ai/ensureAiInsight');

const SP = 'America/Sao_Paulo';

admin.initializeApp();
const db = admin.firestore();

/** `now` (UTC instant) interpretado no calendário de São Paulo. */
function nowSP(now) {
  return DateTime.fromJSDate(now, { zone: 'utc' }).setZone(SP);
}

/**
 * Segunda-feira 00:00 (SP) do início da semana ISO que contém `now` (Luxon: weekday 1=Seg … 7=Dom).
 */
function isoMondayContainingLuxon(now) {
  const d = nowSP(now);
  return d.startOf('day').minus({ days: d.weekday - 1 });
}

/**
 * Segunda (SP) da semana cujo pool se sorteia neste instante.
 * - Domingo (SP): semana ISO que termina nesse domingo → segunda dessa semana.
 * - Seg–Sáb (SP): semana anterior (já fechada no domingo passado).
 */
function submissionWeekMondayLuxon(now) {
  const dt = nowSP(now);
  const mon = isoMondayContainingLuxon(now);
  if (dt.weekday === 7) return mon;
  return mon.minus({ weeks: 1 });
}

/** Chave `YYYY-MM-DD` da segunda do pool (mesmo formato que o app em `submissionWeekId`). */
function contestWeekKeyFromLuxonMonday(monLuxon) {
  return monLuxon.toFormat('yyyy-MM-dd');
}

/** ISO string -> Date ou null. */
function parseIsoDate(s) {
  if (s == null || `${s}`.trim() === '') return null;
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** Primeiro URL de foto não vazio em `public_memories` (vários nomes de campo possíveis). */
function memoryAnyPhotoUrl(row) {
  if (row == null) return '';
  const keys = ['photoUrl', 'photo_url', 'photoPath', 'photo_path'];
  for (const k of keys) {
    if (row[k] != null) {
      const u = `${row[k]}`.trim();
      if (u.length > 0) return u;
    }
  }
  return '';
}

/**
 * URL HTTPS para spotlight / banner — o app Flutter só aceita `https://` (ver weekly_photo_spotlight_visibility).
 */
function memoryPhotoUrl(row) {
  const u = memoryAnyPhotoUrl(row);
  const s = u.toLowerCase();
  if (!s.startsWith('https://')) return '';
  return u.trim();
}

/** UID da mãe em `public_memories` — o app grava `userId` e/ou `owner_uid`. */
function rowUserId(row) {
  if (!row) return '';
  return `${row.userId || row.owner_uid || row.user_id || ''}`.trim();
}

/** Apaga `public_memories` (e curtidas) de uma utilizadora — backup quando o doc `users/{uid}` some. */
async function purgePublicMemoriesForUid(uid) {
  const id = `${uid || ''}`.trim();
  if (!id) return;

  const col = db.collection('public_memories');
  const idField = admin.firestore.FieldPath.documentId();
  const prefix = `${id}_`;
  const seen = new Set();

  async function deleteDocTree(ref) {
    if (!ref || seen.has(ref.id)) return;
    seen.add(ref.id);
    while (true) {
      const likes = await ref.collection('likes').limit(200).get();
      if (likes.empty) break;
      const batch = db.batch();
      for (const d of likes.docs) batch.delete(d.ref);
      await batch.commit();
    }
    await ref.delete();
  }

  for (const field of ['userId', 'owner_uid', 'ownerUid']) {
    while (true) {
      const snap = await col.where(field, '==', id).limit(100).get();
      if (snap.empty) break;
      for (const doc of snap.docs) await deleteDocTree(doc.ref);
      if (snap.size < 100) break;
    }
  }

  let lastDoc = null;
  while (true) {
    let q = col.orderBy(idField).startAt(prefix).endAt(`${prefix}\uf8ff`).limit(100);
    if (lastDoc) {
      q = col.orderBy(idField).startAfter(lastDoc).endAt(`${prefix}\uf8ff`).limit(100);
    }
    const snap = await q.get();
    if (snap.empty) break;
    for (const doc of snap.docs) await deleteDocTree(doc.ref);
    if (snap.size < 100) break;
    lastDoc = snap.docs[snap.docs.length - 1];
  }

  const spotRef = db.collection('weekly_photo_contests').doc('spotlight_current');
  const spot = await spotRef.get();
  if (spot.exists) {
    const s = spot.data() || {};
    const winnerUid = `${s.winner_user_id || s.winnerUserId || ''}`.trim();
    const memId = `${s.winner_public_memory_id || s.winnerPublicMemoryId || ''}`.trim();
    if (winnerUid === id || (memId && memId.startsWith(`${id}_`))) {
      await spotRef.delete();
    }
  }

  const contests = await db.collection('weekly_photo_contests').where('winner_user_id', '==', id).get();
  const batch = db.batch();
  for (const doc of contests.docs) batch.delete(doc.ref);
  if (!contests.empty) await batch.commit();
}

/** Preferir `babyDisplayName` / `babySex` da memória pública ligada ao vencedor (dados frescos). */
async function enrichSpotlightWithPublicMemory(raw) {
  const memId = `${raw.winner_public_memory_id || ''}`.trim();
  if (!memId) return raw;
  const mem = await db.collection('public_memories').doc(memId).get();
  if (!mem.exists) return raw;
  const m = mem.data() || {};
  const out = { ...raw };
  const liveName = `${m.babyDisplayName || ''}`.trim();
  if (liveName) out.winner_baby_display_name = liveName;
  const liveSex = `${m.babySex || ''}`.trim().toUpperCase();
  if (liveSex === 'M' || liveSex === 'F') out.winner_baby_sex = liveSex;
  const babyId = `${m.babyId || ''}`.trim();
  if (babyId) out.winner_baby_id = babyId;
  return out;
}

/** Se `spotlight_current` aponta para esta memória pública, actualiza nome/sexo do bebé. */
async function syncSpotlightWinnerBabyFieldsFromPublicMemory(memId, row) {
  const spotRef = db.collection('weekly_photo_contests').doc('spotlight_current');
  const spot = await spotRef.get();
  if (!spot.exists) return;
  const s = spot.data() || {};
  const winnerId = `${s.winner_public_memory_id || ''}`.trim();
  if (!winnerId || winnerId !== memId) return;

  const displayName = `${row.babyDisplayName || row.baby_display_name || ''}`.trim();
  const sexRaw = `${row.babySex || row.baby_sex || ''}`.trim().toUpperCase();
  const patch = { updated_at: admin.firestore.FieldValue.serverTimestamp() };
  if (displayName) patch.winner_baby_display_name = displayName;
  if (sexRaw === 'M' || sexRaw === 'F') patch.winner_baby_sex = sexRaw;
  const babyId = `${row.babyId || row.baby_id || ''}`.trim();
  if (babyId) patch.winner_baby_id = babyId;
  await spotRef.set(patch, { merge: true });
}

/** Campos do vencedor para `spotlight_current` e histórico `weekly_photo_contests/{weekKey}`. */
function winnerSnapshotFromPick(pick) {
  return {
    winner_public_memory_id: pick.id,
    winner_memory_id: pick.memoryId || pick.id,
    winner_user_id: rowUserId(pick) || null,
    winner_badge_id: pick.badgeId || pick.badge_id || null,
    winner_photo_url: memoryPhotoUrl(pick),
    winner_badge_title: `${pick.badgeTitle || pick.badge_title || ''}`.trim() || '',
    winner_baby_display_name: pick.babyDisplayName || null,
    winner_baby_sex: pick.babySex === 'M' || pick.babySex === 'F' ? pick.babySex : null,
    winner_baby_age_label: pick.babyAgeLabel || null,
    winner_public_description: pick.publicDescription || null,
    winner_memory_date: pick.createdAt || null,
  };
}

/**
 * Histórico semanal em `weekly_photo_contests/{YYYY-MM-DD}` (segunda do pool).
 * Inclui snapshot da foto vencedora e contagem de curtidas (`like_count`).
 */
async function writeWeeklyPhotoWeekHistory(
  weekKey,
  { status, pick, displayStartLuxon, displayUntilLuxon, drawInstant, likeCount = 0 },
) {
  const payload = {
    id: weekKey,
    weekId: weekKey,
    week_id: weekKey,
    status,
    like_count: likeCount,
    winner_like_count: likeCount,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (displayStartLuxon) {
    const ts = admin.firestore.Timestamp.fromDate(displayStartLuxon.toJSDate());
    payload.startsAt = ts;
    payload.draw_at = ts;
    payload.drawAt = ts;
  }
  if (displayUntilLuxon) {
    const ts = admin.firestore.Timestamp.fromDate(displayUntilLuxon.toJSDate());
    payload.endsAt = ts;
    payload.display_until = ts;
    payload.displayUntil = ts;
  }
  if (drawInstant) {
    payload.drawAt = admin.firestore.Timestamp.fromDate(drawInstant);
  }
  if (pick) {
    Object.assign(payload, winnerSnapshotFromPick(pick));
  }
  await db.collection('weekly_photo_contests').doc(weekKey).set(payload, { merge: true });
}

/** Propaga contagem de curtidas para `public_memories` e documentos de concurso relacionados. */
async function propagatePublicMemoryLikeCount(memoryId, delta) {
  const id = `${memoryId || ''}`.trim();
  if (!id || delta === 0) return;

  const memRef = db.collection('public_memories').doc(id);
  let count = 0;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(memRef);
    const current = Math.max(0, Number(snap.data()?.likeCount ?? snap.data()?.like_count ?? 0));
    count = Math.max(0, current + delta);
    tx.set(
      memRef,
      {
        likeCount: count,
        like_count: count,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });

  const batch = db.batch();
  const contests = await db
    .collection('weekly_photo_contests')
    .where('winner_public_memory_id', '==', id)
    .get();
  for (const doc of contests.docs) {
    batch.set(doc.ref, { like_count: count, winner_like_count: count }, { merge: true });
  }
  const spotRef = db.collection('weekly_photo_contests').doc('spotlight_current');
  const spot = await spotRef.get();
  if (`${spot.data()?.winner_public_memory_id || ''}`.trim() === id) {
    batch.set(spotRef, { winner_like_count: count }, { merge: true });
  }
  await batch.commit();
}

/**
 * Candidatos com foto HTTPS: evita `limit(N)` sem critério; pagina a coleção se necessário.
 *
 * @param {number} [opts.minHttps] mínimo de docs com HTTPS a reunir na paginação antes de parar (lista vs seed).
 */
async function loadPublicMemoriesWithPhotoCandidates(
  db,
  { maxOrdered = 120, maxFallback = 400, maxPaginatedScan = 12000, minHttps = 1 } = {},
) {
  const byId = new Map();
  const mergeSnap = (snap) => {
    for (const doc of snap.docs) {
      if (!byId.has(doc.id)) byId.set(doc.id, { id: doc.id, ...doc.data() });
    }
  };

  try {
    mergeSnap(await db.collection('public_memories').orderBy('updated_at', 'desc').limit(maxOrdered).get());
  } catch (e) {
    console.warn('loadPublicMemoriesWithPhotoCandidates: orderBy(updated_at)', e.message || e);
  }

  try {
    mergeSnap(
      await db.collection('public_memories').orderBy('publicEnabledAt', 'desc').limit(maxOrdered).get(),
    );
  } catch (e) {
    console.warn('loadPublicMemoriesWithPhotoCandidates: orderBy(publicEnabledAt)', e.message || e);
  }

  let rows = [...byId.values()];
  let withPhoto = rows.filter((row) => memoryPhotoUrl(row).length > 0);

  if (withPhoto.length === 0) {
    mergeSnap(await db.collection('public_memories').limit(maxFallback).get());
    rows = [...byId.values()];
    withPhoto = rows.filter((row) => memoryPhotoUrl(row).length > 0);
  }

  if (withPhoto.length < minHttps) {
    const seen = new Set(withPhoto.map((r) => r.id));
    const idField = admin.firestore.FieldPath.documentId();
    const pageSize = 400;
    let lastDoc = null;
    let scanned = 0;
    while (withPhoto.length < minHttps && scanned < maxPaginatedScan) {
      let q = db.collection('public_memories').orderBy(idField).limit(pageSize);
      if (lastDoc != null) q = q.startAfter(lastDoc);
      const snap = await q.get();
      if (snap.empty) break;
      for (const doc of snap.docs) {
        const row = { id: doc.id, ...doc.data() };
        if (!seen.has(row.id) && memoryPhotoUrl(row)) {
          seen.add(row.id);
          withPhoto.push(row);
        }
      }
      scanned += snap.docs.length;
      lastDoc = snap.docs[snap.docs.length - 1];
      if (snap.docs.length < pageSize) break;
    }
  }

  withPhoto.sort((a, b) => {
    const ta = a.publicEnabledAt ? new Date(a.publicEnabledAt).getTime() : 0;
    const tb = b.publicEnabledAt ? new Date(b.publicEnabledAt).getTime() : 0;
    return tb - ta;
  });

  return withPhoto;
}

/**
 * Uma entrada por utilizador (`userId`): se várias memórias públicas na mesma semana,
 * fica a que ficou pública primeiro (`publicEnabledAt` mais antigo; empate: doc `id` menor).
 */
function oneCandidatePerUser(rows) {
  const bestByUser = new Map();
  for (const row of rows) {
    const uid = rowUserId(row);
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
 * Sorteia o pool cuja segunda ISO (SP) é [poolMondayLuxon].
 * Exibição na Home: segunda seguinte 00:00 SP até à segunda seguinte (`display_until`).
 *
 * @param {import('luxon').DateTime} poolMondayLuxon segunda 00:00 America/Sao_Paulo do `submissionWeekId`.
 * @param {Date} drawInstant instante do sorteio (meta em `weekly_photo_contests/{weekKey}.drawAt`).
 */
async function runWeeklyPhotoDrawFromPoolMonday(poolMondayLuxon, drawInstant) {
  const subLuxon = poolMondayLuxon.startOf('day');
  const weekKey = contestWeekKeyFromLuxonMonday(subLuxon);
  const displayStart = subLuxon.plus({ weeks: 1 }).startOf('day');
  const displayUntil = displayStart.plus({ weeks: 1 });

  const q = await db
    .collection('public_memories')
    .where('submissionWeekId', '==', weekKey)
    .get();

  const withPhoto = q.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((row) => memoryPhotoUrl(row).length > 0);

  const candidates = oneCandidatePerUser(withPhoto);
  const spotlightRef = db.collection('weekly_photo_contests').doc('spotlight_current');

  if (candidates.length === 0) {
    await spotlightRef.set(
      {
        status: 'inactive',
        week_id: weekKey,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        bypass_display_window: false,
        winner_photo_url: null,
        winner_badge_title: null,
        winner_badge_id: null,
        winner_baby_sex: null,
        winner_user_id: null,
        winner_public_memory_id: null,
        winner_baby_display_name: null,
        winner_baby_age_label: null,
        winner_public_description: null,
        winner_memory_date: null,
        winner_like_count: 0,
        draw_at: null,
        display_until: null,
      },
      { merge: true },
    );
    await writeWeeklyPhotoWeekHistory(weekKey, {
      status: 'inactive',
      pick: null,
      displayStartLuxon: displayStart,
      displayUntilLuxon: displayUntil,
      drawInstant,
      likeCount: 0,
    });
    return {
      weekKey,
      candidateCount: 0,
      status: 'inactive',
      forced: false,
    };
  }

  const pick = candidates[Math.floor(Math.random() * candidates.length)];

  const metaRef = db.collection('weekly_photo_contests').doc('_meta');
  const metaSnap = await metaRef.get();
  const firstSpotlightDone = metaSnap.exists && metaSnap.data()?.first_spotlight_completed === true;
  /** Primeiro sorteio com vencedor: mostrar a todos mesmo fora da janela (cliente lê este campo). */
  const bypassDisplayWindow = !firstSpotlightDone;

  await spotlightRef.set({
    status: 'active',
    week_id: weekKey,
    bypass_display_window: bypassDisplayWindow,
    draw_at: admin.firestore.Timestamp.fromDate(displayStart.toJSDate()),
    display_until: admin.firestore.Timestamp.fromDate(displayUntil.toJSDate()),
    ...winnerSnapshotFromPick(pick),
    winner_like_count: 0,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  if (bypassDisplayWindow) {
    await metaRef.set(
      {
        first_spotlight_completed: true,
        first_spotlight_week_id: weekKey,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  await writeWeeklyPhotoWeekHistory(weekKey, {
    status: 'active',
    pick,
    displayStartLuxon: displayStart,
    displayUntilLuxon: displayUntil,
    drawInstant,
    likeCount: 0,
  });

  return {
    weekKey,
    candidateCount: candidates.length,
    status: 'active',
    winnerPublicMemoryId: pick.id,
    winnerUserId: rowUserId(pick) || null,
    bypass_display_window: bypassDisplayWindow,
    forced: false,
  };
}

/**
 * Sorteia a partir do pool da semana inferida por **agora** (America/Sao_Paulo).
 */
async function runWeeklyPhotoDraw(now) {
  const poolMonday = submissionWeekMondayLuxon(now);
  return runWeeklyPhotoDrawFromPoolMonday(poolMonday, now);
}

/**
 * Domingo ~23:58 (America/Sao_Paulo) — sorteia o pool da semana que acaba nesse domingo.
 * Se já existir destaque **ativo** para este mesmo `week_id`, não volta a sortear.
 */
exports.scheduleWeeklyPhotoDraw = onSchedule(
  {
    schedule: '58 23 * * SUN',
    timeZone: 'America/Sao_Paulo',
    region: 'southamerica-east1',
  },
  async () => {
    const now = new Date();
    const subLuxon = submissionWeekMondayLuxon(now);
    const weekKey = contestWeekKeyFromLuxonMonday(subLuxon);
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
 * Força o mesmo sorteio que o cron de domingo (`runWeeklyPhotoDraw(new Date())`), **sem** o
 * “skip” quando já existe destaque para o mesmo `week_id` (útil se o domingo 23:58 falhou ou
 * queres correr hoje ao meio-dia via Cloud Scheduler HTTP).
 *
 * Protegido por `FORCE_WEEKLY_DRAW_SECRET`: query `?secret=...` ou header `x-force-weekly-draw-secret`.
 * GET/POST.
 */
exports.forceWeeklyPhotoDraw = onRequest(
  {
    region: 'southamerica-east1',
    cors: false,
    invoker: 'public',
    secrets: [forceWeeklyDrawSecret],
  },
  async (req, res) => {
    if (req.method !== 'GET' && req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }
    const headerSecret = `${req.get('x-force-weekly-draw-secret') || ''}`.trim();
    const querySecret = `${req.query.secret || ''}`.trim();
    const token = headerSecret || querySecret;
    const expected = forceWeeklyDrawSecret.value();
    if (!expected || !token || token !== expected) {
      res.status(403).json({ error: 'forbidden' });
      return;
    }
    try {
      const result = await runWeeklyPhotoDraw(new Date());
      res.status(200).json({ ok: true, ...result });
    } catch (e) {
      console.error('forceWeeklyPhotoDraw', e);
      res.status(500).json({ error: `${e.message || e}` });
    }
  },
);

/**
 * Seed inicial: escreve `spotlight_current` com `bypass_display_window: true` (banner aparece
 * para toda a gente, independentemente da janela). Picks:
 * 1. Se `?winnerMemoryId` for indicado, usa esse documento de `public_memories`.
 * 2. Caso contrário, primeiro candidato encontrado em `public_memories` com `photoUrl` válido.
 *
 * Modo **bootstrap (sem secret)**: permitido apenas se `spotlight_current` ainda não existir, ou
 * não tiver `winner_photo_url`, ou tiver `status === 'inactive'`. Depois disso passa a exigir o
 * mesmo secret de `forceWeeklyPhotoDraw`.
 *
 * GET/POST. Parâmetros opcionais: `winnerMemoryId`, `photoUrl`, `badgeTitle`, `babyDisplayName`,
 * `babySex` (`M`|`F`), `babyAgeLabel`, `publicDescription`, `weekKey` (segunda SP, opcional).
 */
exports.seedSpotlightWinner = onRequest(
  {
    region: 'southamerica-east1',
    cors: false,
    invoker: 'public',
  },
  async (req, res) => {
    if (req.method !== 'GET' && req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    try {
      const spotlightRef = db.collection('weekly_photo_contests').doc('spotlight_current');
      const cur = (await spotlightRef.get()).data() || {};

      const hasActiveWinner =
        cur.status === 'active' && typeof cur.winner_photo_url === 'string' && cur.winner_photo_url.length > 0;

      if (hasActiveWinner && req.query.force !== '1') {
        res.status(409).json({
          error: 'spotlight_current already has an active winner; pass ?force=1 to overwrite',
          current: {
            week_id: cur.week_id || null,
            winner_user_id: cur.winner_user_id || null,
            winner_badge_title: cur.winner_badge_title || null,
          },
        });
        return;
      }

      let pick = null;
      const memoryIdParam = `${req.query.winnerMemoryId || ''}`.trim();
      if (memoryIdParam) {
        const memSnap = await db.collection('public_memories').doc(memoryIdParam).get();
        if (!memSnap.exists) {
          res.status(404).json({ error: `public_memories/${memoryIdParam} not found` });
          return;
        }
        pick = { id: memSnap.id, ...memSnap.data() };
      } else {
        const withPhoto = await loadPublicMemoriesWithPhotoCandidates(db, {
          maxOrdered: 120,
          maxFallback: 400,
          minHttps: 1,
        });
        if (withPhoto.length > 0) pick = withPhoto[0];
      }

      const photoUrlOverride = `${req.query.photoUrl || ''}`.trim();
      const badgeTitleOverride = `${req.query.badgeTitle || ''}`.trim();
      const babyDisplayNameOverride = `${req.query.babyDisplayName || ''}`.trim();
      const babySexOverride = `${req.query.babySex || ''}`.trim().toUpperCase();
      const babyAgeLabelOverride = `${req.query.babyAgeLabel || ''}`.trim();
      const publicDescOverride = `${req.query.publicDescription || ''}`.trim();

      let photoUrl = photoUrlOverride || (pick ? memoryPhotoUrl(pick) : '');
      const rawBadge = pick ? `${pick.badgeTitle || pick.badge_title || ''}`.trim() : '';
      const badgeTitle = badgeTitleOverride || rawBadge || 'Foto da Semana';

      if (photoUrlOverride && !photoUrlOverride.toLowerCase().startsWith('https://')) {
        res.status(400).json({
          error: 'photoUrl must start with https:// (the app banner rejects non-HTTPS URLs)',
        });
        return;
      }

      if (!photoUrl) {
        res.status(400).json({
          error:
            'no public_memories document with an HTTPS photo URL was found. ' +
            'The Flutter app only shows the weekly banner when winner_photo_url is https:// ' +
            '(Firebase Storage, etc.). Local file paths in Firestore do not count.',
          hint:
            'Ensure at least one public memory has been synced with a cloud HTTPS image, deploy these functions, ' +
            'or call with ?photoUrl=https://...&badgeTitle=... plus ?winnerMemoryId=... if you need a manual test ' +
            '(the banner also requires winner_user_id + winner_public_memory_id from a real doc).',
        });
        return;
      }

      const now = new Date();
      const weekKeyParam = `${req.query.weekKey || ''}`.trim();
      let displayStartLuxon;
      let displayUntilLuxon;
      let weekKey;
      if (weekKeyParam && /^\d{4}-\d{2}-\d{2}$/.test(weekKeyParam)) {
        const mon = DateTime.fromISO(weekKeyParam, { zone: SP }).startOf('day');
        if (mon.isValid && mon.weekday === 1) {
          weekKey = weekKeyParam;
          displayStartLuxon = mon.plus({ weeks: 1 }).startOf('day');
          displayUntilLuxon = displayStartLuxon.plus({ weeks: 1 });
        }
      }
      if (!displayStartLuxon) {
        const mon = submissionWeekMondayLuxon(now);
        weekKey = contestWeekKeyFromLuxonMonday(mon);
        displayStartLuxon = mon.plus({ weeks: 1 }).startOf('day');
        displayUntilLuxon = displayStartLuxon.plus({ weeks: 1 });
      }

      const sex = babySexOverride === 'M' || babySexOverride === 'F'
        ? babySexOverride
        : (pick && (pick.babySex === 'M' || pick.babySex === 'F') ? pick.babySex : null);

      const data = {
        status: 'active',
        week_id: weekKey,
        bypass_display_window: true,
        draw_at: admin.firestore.Timestamp.fromDate(displayStartLuxon.toJSDate()),
        display_until: admin.firestore.Timestamp.fromDate(displayUntilLuxon.toJSDate()),
        winner_public_memory_id: (pick && pick.id) || null,
        winner_user_id: (pick && rowUserId(pick)) || null,
        winner_badge_id: (pick && (pick.badgeId || pick.badge_id)) || null,
        winner_photo_url: photoUrl,
        winner_badge_title: badgeTitle,
        winner_baby_display_name: babyDisplayNameOverride || (pick && pick.babyDisplayName) || null,
        winner_baby_sex: sex,
        winner_baby_age_label: babyAgeLabelOverride || (pick && pick.babyAgeLabel) || null,
        winner_public_description: publicDescOverride || (pick && pick.publicDescription) || null,
        winner_memory_date: (pick && pick.createdAt) || now.toISOString(),
        winner_like_count: 0,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      };

      await spotlightRef.set(data, { merge: true });

      if (pick) {
        await writeWeeklyPhotoWeekHistory(weekKey, {
          status: 'active',
          pick: {
            ...pick,
            babyDisplayName: data.winner_baby_display_name,
            babySex: sex,
            babyAgeLabel: data.winner_baby_age_label,
          },
          displayStartLuxon,
          displayUntilLuxon,
          drawInstant: now,
          likeCount: 0,
        });
      }

      await db.collection('weekly_photo_contests').doc('_meta').set(
        {
          first_spotlight_completed: true,
          first_spotlight_week_id: weekKey,
          seeded_at: admin.firestore.FieldValue.serverTimestamp(),
          seeded_via: 'seedSpotlightWinner',
        },
        { merge: true },
      );

      res.status(200).json({
        seeded: true,
        weekKey,
        winnerPublicMemoryId: data.winner_public_memory_id,
        winnerPhotoUrl: data.winner_photo_url,
        winnerBadgeTitle: data.winner_badge_title,
        bypass_display_window: true,
      });
    } catch (e) {
      console.error('seedSpotlightWinner', e);
      res.status(500).json({ error: `${e.message || e}` });
    }
  },
);

/**
 * Endpoint público (sem secret) só para diagnóstico: devolve o documento
 * `weekly_photo_contests/spotlight_current` cru tal como está no Firestore.
 */
exports.inspectSpotlight = onRequest(
  {
    region: 'southamerica-east1',
    cors: false,
    invoker: 'public',
  },
  async (req, res) => {
    try {
      const snap = await db.collection('weekly_photo_contests').doc('spotlight_current').get();
      if (!snap.exists) {
        res.status(200).json({ exists: false });
        return;
      }
      const raw = await enrichSpotlightWithPublicMemory(snap.data() || {});
      // Converter Timestamps para ISO para inspecionar fácil.
      const normalised = Object.fromEntries(
        Object.entries(raw).map(([k, v]) => [k, v && v.toDate ? v.toDate().toISOString() : v]),
      );
      res.status(200).json({ exists: true, data: normalised });
    } catch (e) {
      console.error('inspectSpotlight', e);
      res.status(500).json({ error: `${e.message || e}` });
    }
  },
);

/**
 * Lista os candidatos actuais em `public_memories` que têm `photoUrl` (limit 50).
 *
 * Útil para escolher manualmente um `winnerMemoryId` para `seedSpotlightWinner` ou
 * `pickRandomSpotlightFromPublicMemories`. Retorna campos diagnósticos suficientes
 * para identificar o bebê / dono / descrição.
 *
 * GET público (sem secret).
 */
exports.listPublicMemoryCandidates = onRequest(
  {
    region: 'southamerica-east1',
    cors: false,
    invoker: 'public',
  },
  async (req, res) => {
    try {
      const limit = Math.max(1, Math.min(50, parseInt(`${req.query.limit || '20'}`, 10) || 20));
      const withPhoto = await loadPublicMemoriesWithPhotoCandidates(db, {
        maxOrdered: 100,
        maxFallback: 350,
        minHttps: 1,
      });
      const rows = withPhoto.slice(0, limit).map((row) => ({
          id: row.id,
          submissionWeekId: row.submissionWeekId || null,
          userId: rowUserId(row) || null,
          babyId: row.babyId || null,
          photoUrl: memoryPhotoUrl(row),
          badgeTitle: row.badgeTitle || row.badge_title || null,
          babyDisplayName: row.babyDisplayName || null,
          babySex: row.babySex || null,
          babyAgeLabel: row.babyAgeLabel || null,
          publicDescription: row.publicDescription || null,
          publicEnabledAt: row.publicEnabledAt || null,
          createdAt: row.createdAt || null,
        }));
      res.status(200).json({ count: rows.length, candidates: rows });
    } catch (e) {
      console.error('listPublicMemoryCandidates', e);
      res.status(500).json({ error: `${e.message || e}` });
    }
  },
);

/**
 * Sorteia aleatoriamente entre os candidatos de `public_memories` (com `photoUrl`),
 * aplica `oneCandidatePerUser` e popula `spotlight_current` com **todos** os campos do
 * vencedor — fazendo best-effort em `babies/{babyId}` quando algum campo estiver vazio,
 * para evitar cartões “foto genérica e sem informação”.
 *
 * Útil para fase de testes (2-3 utilizadores) — basta chamar e o banner mostra um deles.
 *
 * Protegido com `?confirm=YES`. Parâmetros opcionais (override do vencedor sorteado):
 *   `winnerMemoryId`, `weekKey` (YYYY-MM-DD, segunda SP).
 *
 * GET/POST público (sem secret).
 */
exports.pickRandomSpotlightFromPublicMemories = onRequest(
  {
    region: 'southamerica-east1',
    cors: false,
    invoker: 'public',
  },
  async (req, res) => {
    try {
      const confirm = `${req.query.confirm || ''}`.trim();
      if (confirm !== 'YES') {
        res.status(400).json({
          error: 'pass ?confirm=YES to overwrite spotlight_current',
        });
        return;
      }

      let pick = null;
      const memoryIdParam = `${req.query.winnerMemoryId || ''}`.trim();
      if (memoryIdParam) {
        const memSnap = await db.collection('public_memories').doc(memoryIdParam).get();
        if (!memSnap.exists) {
          res.status(404).json({ error: `public_memories/${memoryIdParam} not found` });
          return;
        }
        pick = { id: memSnap.id, ...memSnap.data() };
      } else {
        const withPhoto = await loadPublicMemoriesWithPhotoCandidates(db, {
          maxOrdered: 150,
          maxFallback: 500,
          minHttps: 1,
        });
        const candidates = oneCandidatePerUser(withPhoto);
        if (candidates.length === 0) {
          res.status(404).json({
            error: 'no public_memories with an HTTPS photoUrl available (app requires https://)',
          });
          return;
        }
        pick = candidates[Math.floor(Math.random() * candidates.length)];
      }

      // Best-effort: completar campos vazios a partir de `babies/{babyId}`.
      let babyDisplayName = pick.babyDisplayName || null;
      let babySex = pick.babySex === 'M' || pick.babySex === 'F' ? pick.babySex : null;
      let babyAgeLabel = pick.babyAgeLabel || null;
      if ((!babyDisplayName || !babySex || !babyAgeLabel) && pick.babyId) {
        try {
          const babySnap = await db.collection('babies').doc(`${pick.babyId}`).get();
          if (babySnap.exists) {
            const b = babySnap.data() || {};
            babyDisplayName = babyDisplayName || b.displayName || b.name || null;
            if (!babySex) {
              const s = `${b.sex || b.gender || ''}`.trim().toUpperCase();
              if (s === 'M' || s === 'F') babySex = s;
            }
            babyAgeLabel = babyAgeLabel || b.ageLabel || null;
          }
        } catch (e) {
          console.warn('pickRandomSpotlight: babies lookup failed', e);
        }
      }

      const now = new Date();
      const weekKeyParam = `${req.query.weekKey || ''}`.trim();
      let displayStartLuxon;
      let displayUntilLuxon;
      let weekKey;
      if (weekKeyParam && /^\d{4}-\d{2}-\d{2}$/.test(weekKeyParam)) {
        const mon = DateTime.fromISO(weekKeyParam, { zone: SP }).startOf('day');
        if (mon.isValid && mon.weekday === 1) {
          weekKey = weekKeyParam;
          displayStartLuxon = mon.plus({ weeks: 1 }).startOf('day');
          displayUntilLuxon = displayStartLuxon.plus({ weeks: 1 });
        }
      }
      if (!displayStartLuxon) {
        const mon = submissionWeekMondayLuxon(now);
        weekKey = contestWeekKeyFromLuxonMonday(mon);
        displayStartLuxon = mon.plus({ weeks: 1 }).startOf('day');
        displayUntilLuxon = displayStartLuxon.plus({ weeks: 1 });
      }

      const data = {
        status: 'active',
        week_id: weekKey,
        bypass_display_window: true,
        draw_at: admin.firestore.Timestamp.fromDate(displayStartLuxon.toJSDate()),
        display_until: admin.firestore.Timestamp.fromDate(displayUntilLuxon.toJSDate()),
        winner_public_memory_id: pick.id,
        winner_user_id: rowUserId(pick) || null,
        winner_badge_id: pick.badgeId || pick.badge_id || null,
        winner_photo_url: memoryPhotoUrl(pick),
        winner_badge_title: `${pick.badgeTitle || pick.badge_title || ''}`.trim() || 'Foto da Semana',
        winner_baby_display_name: babyDisplayName,
        winner_baby_sex: babySex,
        winner_baby_age_label: babyAgeLabel,
        winner_public_description: pick.publicDescription || null,
        winner_memory_date: pick.createdAt || now.toISOString(),
        winner_like_count: 0,
        cleared_at: null,
        cleared_via: null,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      };

      await db.collection('weekly_photo_contests').doc('spotlight_current').set(data, { merge: true });

      const pickForHistory = {
        ...pick,
        babyDisplayName,
        babySex,
        babyAgeLabel,
      };
      await writeWeeklyPhotoWeekHistory(weekKey, {
        status: 'active',
        pick: pickForHistory,
        displayStartLuxon,
        displayUntilLuxon,
        drawInstant: now,
        likeCount: 0,
      });

      await db.collection('weekly_photo_contests').doc('_meta').set(
        {
          first_spotlight_completed: true,
          first_spotlight_week_id: weekKey,
          seeded_at: admin.firestore.FieldValue.serverTimestamp(),
          seeded_via: 'pickRandomSpotlightFromPublicMemories',
        },
        { merge: true },
      );

      res.status(200).json({
        ok: true,
        weekKey,
        winnerPublicMemoryId: pick.id,
        winnerUserId: rowUserId(pick) || null,
        winnerBabyDisplayName: babyDisplayName,
        winnerBabyAgeLabel: babyAgeLabel,
        winnerBabySex: babySex,
        hasDescription: !!pick.publicDescription,
        photoUrl: memoryPhotoUrl(pick),
      });
    } catch (e) {
      console.error('pickRandomSpotlightFromPublicMemories', e);
      res.status(500).json({ error: `${e.message || e}` });
    }
  },
);

/**
 * Limpa o documento `spotlight_current` (marca como inactivo e remove campos do vencedor).
 *
 * Útil quando um seed de teste deixou o banner com foto genérica / sem nome / descrição.
 * Não toca em `_meta.first_spotlight_completed` — o próximo sorteio real volta a popular.
 *
 * Protegido com `?confirm=YES` para evitar limpeza acidental.
 * GET/POST público (sem secret) — semelhante a `inspectSpotlight`.
 */
exports.clearSpotlight = onRequest(
  {
    region: 'southamerica-east1',
    cors: false,
    invoker: 'public',
  },
  async (req, res) => {
    try {
      const confirm = `${req.query.confirm || ''}`.trim();
      if (confirm !== 'YES') {
        res.status(400).json({
          error: 'pass ?confirm=YES to clear spotlight_current',
        });
        return;
      }
      const spotlightRef = db.collection('weekly_photo_contests').doc('spotlight_current');
      await spotlightRef.set(
        {
          status: 'inactive',
          bypass_display_window: false,
          winner_public_memory_id: null,
          winner_user_id: null,
          winner_photo_url: null,
          winner_badge_title: null,
          winner_badge_id: null,
          winner_baby_display_name: null,
          winner_baby_sex: null,
          winner_baby_age_label: null,
          winner_public_description: null,
          winner_memory_date: null,
          cleared_at: admin.firestore.FieldValue.serverTimestamp(),
          cleared_via: 'clearSpotlight',
        },
        { merge: true },
      );
      res.status(200).json({ cleared: true });
    } catch (e) {
      console.error('clearSpotlight', e);
      res.status(500).json({ error: `${e.message || e}` });
    }
  },
);

/**
 * Mantém `likeCount` em `public_memories` e `like_count` / `winner_like_count` no histórico
 * semanal e em `spotlight_current` quando a memória vencedora recebe ou perde curtidas.
 */
/** Caminho do objeto no bucket a partir de URL HTTPS do Firebase Storage. */
function storageObjectPathFromHttpsUrl(url) {
  try {
    const u = new URL(url);
    const idx = u.pathname.indexOf('/o/');
    if (idx < 0) return '';
    return decodeURIComponent(u.pathname.slice(idx + 3));
  } catch (e) {
    return '';
  }
}

const PANEL_ADMIN_ROLES = new Set(['owner', 'admin']);

function normalizeAdminEmail(raw) {
  return `${raw || ''}`.trim().toLowerCase();
}

function parsePanelRole(raw) {
  const role = `${raw || ''}`.trim().toLowerCase();
  return PANEL_ADMIN_ROLES.has(role) ? role : null;
}

/** Resolve admin role from allowlist, legacy admins/{uid}, or ADMIN_BOOTSTRAP_EMAILS. */
async function resolveAdminRoleForEmail(emailKey) {
  if (!emailKey) return null;

  const listed = await db.collection('admins_by_email').doc(emailKey).get();
  if (listed.exists) {
    const d = listed.data() || {};
    const role = parsePanelRole(d.role);
    if (d.active === true && role) {
      return { role, source: 'allowlist' };
    }
  }

  const legacy = await db.collection('admins').where('email', '==', emailKey).limit(10).get();
  for (const doc of legacy.docs) {
    const d = doc.data() || {};
    const role = parsePanelRole(d.role);
    if (d.active === true && role) {
      return { role, source: 'legacy', legacyUid: doc.id };
    }
  }

  const bootstrapRaw = `${process.env.ADMIN_BOOTSTRAP_EMAILS || ''}`;
  const bootstrap = bootstrapRaw
    .split(',')
    .map((s) => normalizeAdminEmail(s))
    .filter(Boolean);
  if (bootstrap.includes(emailKey)) {
    return { role: 'owner', source: 'bootstrap' };
  }

  return null;
}

async function linkAdminPanelSession(uid, emailKey, role) {
  const batch = db.batch();
  batch.set(
    db.collection('admins_by_email').doc(emailKey),
    {
      email: emailKey,
      role,
      active: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  batch.set(
    db.collection('admins').doc(uid),
    {
      email: emailKey,
      role,
      active: true,
      linkedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await batch.commit();
}

async function assertPanelAdmin(uid) {
  const doc = await db.collection('admins').doc(uid).get();
  if (!doc.exists) throw new HttpsError('permission-denied', 'Not an admin');
  const d = doc.data() || {};
  if (d.active !== true) throw new HttpsError('permission-denied', 'Admin inactive');
  const role = parsePanelRole(d.role);
  if (!role) {
    throw new HttpsError('permission-denied', 'Insufficient role');
  }
}

/**
 * Callable — liga admins/{uid} ao e-mail allowlisted (ou legacy/bootstrap).
 * Usado pelo painel após apagar/recriar conta do app (novo Firebase Auth UID).
 */
exports.ensureAdminPanelAccess = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in required');
    }
    const emailKey = normalizeAdminEmail(request.auth.token.email);
    if (!emailKey) {
      throw new HttpsError('failed-precondition', 'Sign in with an account that has an email');
    }

    const resolved = await resolveAdminRoleForEmail(emailKey);
    if (!resolved) {
      throw new HttpsError('permission-denied', 'Not an admin');
    }

    await linkAdminPanelSession(request.auth.uid, emailKey, resolved.role);
    return {
      ok: true,
      email: emailKey,
      role: resolved.role,
      source: resolved.source,
    };
  },
);

/**
 * Callable — devolve foto em base64 para o painel admin (Storage SDK no browser falha
 * por regras/CORS). Requer login Firebase + documento `admins/{uid}` owner/admin ativo.
 */
exports.adminGetPhotoBytes = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required');
    await assertPanelAdmin(request.auth.uid);

    const url = `${request.data?.url || ''}`.trim();
    const storagePath = `${request.data?.storagePath || ''}`.trim();
    const bucket = admin.storage().bucket();
    let buffer;

    if (storagePath) {
      const [buf] = await bucket.file(storagePath).download();
      buffer = buf;
    } else if (url.toLowerCase().startsWith('https://')) {
      const objectPath = storageObjectPathFromHttpsUrl(url);
      if (objectPath) {
        try {
          const [buf] = await bucket.file(objectPath).download();
          buffer = buf;
        } catch (e) {
          console.warn('adminGetPhotoBytes bucket.download failed, trying fetch', objectPath, e);
          const res = await fetch(url);
          if (!res.ok) throw new HttpsError('not-found', `Photo not found (${res.status})`);
          buffer = Buffer.from(await res.arrayBuffer());
        }
      } else {
        const res = await fetch(url);
        if (!res.ok) throw new HttpsError('not-found', `Photo not found (${res.status})`);
        buffer = Buffer.from(await res.arrayBuffer());
      }
    } else {
      throw new HttpsError('invalid-argument', 'url or storagePath required');
    }

    const maxBytes = 12 * 1024 * 1024;
    if (buffer.length > maxBytes) {
      throw new HttpsError('resource-exhausted', 'Photo too large');
    }

    return {
      bytes: buffer.toString('base64'),
      contentType: 'image/jpeg',
    };
  },
);

/** Quando o perfil `users/{uid}` é apagado, remove candidatos órfãos no Admin / Weekly Photo. */
exports.onUserProfileDeleted = onDocumentDeleted(
  {
    document: 'users/{uid}',
    region: 'southamerica-east1',
  },
  async (event) => {
    const uid = `${event.params.uid || ''}`.trim();
    if (!uid) return;
    try {
      await purgePublicMemoriesForUid(uid);
      console.log('onUserProfileDeleted: purged public_memories for', uid);
    } catch (e) {
      console.error('onUserProfileDeleted', uid, e);
      throw e;
    }
  },
);

exports.onPublicMemoryLikeWritten = onDocumentWritten(
  {
    document: 'public_memories/{memoryId}/likes/{likeUid}',
    region: 'southamerica-east1',
  },
  async (event) => {
    const before = event.data.before.exists;
    const after = event.data.after.exists;
    if (before === after) return;
    const delta = !before && after ? 1 : before && !after ? -1 : 0;
    if (delta === 0) return;
    try {
      await propagatePublicMemoryLikeCount(event.params.memoryId, delta);
    } catch (e) {
      console.error('onPublicMemoryLikeWritten', e);
      throw e;
    }
  },
);

/** Quando a mãe actualiza nome/sexo, `public_memories` é regravado e o destaque segue em sync. */
exports.onPublicMemoryWritten = onDocumentWritten(
  {
    document: 'public_memories/{memoryId}',
    region: 'southamerica-east1',
  },
  async (event) => {
    if (!event.data.after.exists) return;
    const memId = event.params.memoryId;
    const after = event.data.after.data() || {};
    try {
      await syncSpotlightWinnerBabyFieldsFromPublicMemory(memId, after);
    } catch (e) {
      console.error('onPublicMemoryWritten', e);
    }
  },
);

const adminBroadcast = createAdminBroadcastHandlers({
  onCall,
  db,
  admin,
});
exports.previewAdminBroadcastAudience = adminBroadcast.previewAdminBroadcastAudience;
exports.publishAdminBroadcast = adminBroadcast.publishAdminBroadcast;

/** IA Babá — chat (Premium + limite diário no servidor). */
exports.askAiNanny = askAiNanny;

/** IA Babá — apagar conversa / mensagem; poda automática do histórico. */
exports.manageAiNannyChat = manageAiNannyChat;

/** IA Babá — voz neural OpenAI (TTS HD) para ouvir respostas. */
exports.synthesizeAiNannySpeech = synthesizeAiNannySpeech;

/** Registro por voz — transcrição + interpretação (sem salvar; confirmação no app). */
exports.processVoiceRecord = processVoiceRecord;
exports.processTextRecord = processTextRecord;

/** IA Babá — extrai registros estruturados (gpt-4o-mini, sem histórico de chat). */
exports.parseAiNannyMessage = parseAiNannyMessage;

/** Insight IA Babá (resumo diário/semanal — cache em `ai_insights`). */
exports.ensureAiInsight = ensureAiInsight;

/** Horóscopo familiar diário (cache por dia em `family_horoscopes`). */
exports.generateDailyFamilyHoroscope = createGenerateDailyFamilyHoroscope({
  onCall,
  HttpsError,
  db,
  openAiApiKey,
});
