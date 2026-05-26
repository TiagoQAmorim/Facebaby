const { HttpsError } = require('firebase-functions/v2/https');
const { FieldValue, FieldPath } = require('firebase-admin/firestore');

const MAX_TEXT = 320;
const MAX_IMAGE_BYTES = 900 * 1024;
const BATCH_SIZE = 400;

function normalizeCountry(raw) {
  const c = `${raw || ''}`.trim().toUpperCase();
  return c.length === 2 ? c : '';
}

function babyAgeMonths(birthRaw, now = new Date()) {
  if (!birthRaw) return null;
  const iso = `${birthRaw}`.includes('T') ? `${birthRaw}` : `${birthRaw}T12:00:00`;
  const birth = new Date(iso);
  if (Number.isNaN(birth.getTime())) return null;
  const days = Math.max(0, (now - birth) / (86400000));
  return Math.floor(days / 30.44);
}

function userCountryCode(user) {
  const direct = normalizeCountry(
    user.countryCode || user.country_code || user.appCountry,
  );
  if (direct) return direct;
  const locale = `${user.localeCountry || user.locale_country || ''}`.trim();
  if (locale.includes('_')) {
    const part = locale.split('_').pop();
    return normalizeCountry(part);
  }
  if (locale.includes('-')) {
    const part = locale.split('-').pop();
    return normalizeCountry(part);
  }
  return normalizeCountry(locale);
}

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

async function listAllUserDocs(db, maxUsers = 8000) {
  const out = [];
  let last = null;
  while (out.length < maxUsers) {
    let q = db.collection('users').orderBy(FieldPath.documentId()).limit(500);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      out.push({ uid: doc.id, data: doc.data() || {} });
    }
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < 500) break;
  }
  return out;
}

async function loadUserBabies(db, uid) {
  const snap = await db.collection('users').doc(uid).collection('babies').limit(8).get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

function matchesBabyAge(babies, minMonths, maxMonths) {
  if (!babies.length) return false;
  const now = new Date();
  for (const b of babies) {
    const months = babyAgeMonths(b.birth_date || b.birthDate, now);
    if (months == null) continue;
    if (months >= minMonths && months <= maxMonths) return true;
  }
  return false;
}

async function resolveTargetUids(db, targeting) {
  const type = `${targeting?.type || 'all'}`.trim().toLowerCase();
  const explicit = Array.isArray(targeting?.userIds)
    ? targeting.userIds.map((u) => `${u || ''}`.trim()).filter(Boolean)
    : [];

  if (type === 'users') {
    return [...new Set(explicit)];
  }

  const minMonths = Math.max(0, parseInt(`${targeting?.ageMinMonths ?? 0}`, 10) || 0);
  const maxMonths = Math.min(
    72,
    parseInt(`${targeting?.ageMaxMonths ?? 72}`, 10) || 72,
  );
  const countries = Array.isArray(targeting?.countryCodes)
    ? targeting.countryCodes.map(normalizeCountry).filter(Boolean)
    : [];

  const users = await listAllUserDocs(db);
  const uids = [];

  for (const { uid, data } of users) {
    if (`${data.status || ''}`.trim().toLowerCase() === 'suspended') continue;

    if (type === 'country') {
      if (!countries.length) continue;
      const cc = userCountryCode(data);
      if (!cc || !countries.includes(cc)) continue;
      uids.push(uid);
      continue;
    }

    if (type === 'baby_age') {
      const babies = await loadUserBabies(db, uid);
      if (matchesBabyAge(babies, minMonths, maxMonths)) uids.push(uid);
      continue;
    }

    // all
    uids.push(uid);
  }

  return uids;
}

function firebaseDownloadUrl(bucketName, storagePath) {
  const encoded = encodeURIComponent(storagePath);
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encoded}?alt=media`;
}

function normalizeActionUrl(raw) {
  const u = `${raw || ''}`.trim();
  if (!u) return null;
  try {
    const parsed = new URL(u.includes('://') ? u : `https://${u}`);
    if (parsed.protocol !== 'https:') return null;
    return parsed.toString();
  } catch (_) {
    return null;
  }
}

function normalizeImageUrl(raw) {
  const u = `${raw || ''}`.trim();
  if (!u) return null;
  try {
    const parsed = new URL(u.includes('://') ? u : `https://${u}`);
    if (parsed.protocol !== 'https:') return null;
    return parsed.toString();
  } catch (_) {
    return null;
  }
}

const FLOATING_MESSAGE_TYPES = new Set([
  'admin_ad',
  'admin_notice',
  'promo_banner',
  'ai_tip',
  'ai_summary',
  'ai_alert',
  'premium_offer',
]);

const FLOATING_DISMISS_MODES = new Set([
  'close_button',
  'drag_to_dismiss',
  'both',
]);

const FLOATING_TARGET_AUDIENCES = new Set([
  'all',
  'free_users',
  'premium_users',
  'plus_users',
  'no_subscription',
  'baby_under_6m',
  'baby_under_6_months',
  'baby_over_6m',
  'baby_over_6_months',
  'ai_active',
]);

function normalizeFloatingMessageType(raw) {
  const v = `${raw || ''}`.trim().toLowerCase();
  return FLOATING_MESSAGE_TYPES.has(v) ? v : 'admin_ad';
}

function normalizeFloatingTargetAudience(raw) {
  const v = `${raw || ''}`.trim().toLowerCase();
  return FLOATING_TARGET_AUDIENCES.has(v) ? v : 'all';
}

function normalizeFloatingDismissMode(raw) {
  const v = `${raw || ''}`.trim().toLowerCase();
  return FLOATING_DISMISS_MODES.has(v) ? v : 'both';
}

function parseOptionalIsoDate(raw) {
  if (raw == null || raw === '') return null;
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return null;
  return d;
}

function normalizeActionButtonLabel(raw) {
  const s = `${raw || ''}`.trim();
  if (!s) return null;
  return s.slice(0, 48);
}

async function uploadBroadcastImage(admin, bucket, campaignId, imageBase64) {
  const raw = `${imageBase64 || ''}`.trim();
  if (!raw) return null;
  const b64 = raw.includes(',') ? raw.split(',').pop() : raw;
  const buffer = Buffer.from(b64, 'base64');
  if (!buffer.length) return null;
  if (buffer.length > MAX_IMAGE_BYTES) {
    throw new HttpsError('invalid-argument', 'Imagem muito grande (máx. 900 KB).');
  }
  const path = `admin_broadcasts/${campaignId}.jpg`;
  const file = bucket.file(path);
  await file.save(buffer, {
    metadata: { contentType: 'image/jpeg', cacheControl: 'public,max-age=86400' },
  });
  try {
    await file.makePublic();
  } catch (e) {
    console.warn('adminBroadcast makePublic', e);
  }
  return firebaseDownloadUrl(bucket.name, path);
}

function createAdminBroadcastHandlers({ onCall, db, admin }) {
  const bucket = admin.storage().bucket();

  const previewAdminBroadcastAudience = onCall(
    { region: 'southamerica-east1' },
    async (request) => {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'Sign in required');
      }
      await assertPanelAdmin(db, request.auth.uid);
      const uids = await resolveTargetUids(db, request.data?.targeting || {});
      return { count: uids.length };
    },
  );

  const publishAdminBroadcast = onCall(
    { region: 'southamerica-east1', timeoutSeconds: 540, memory: '1GiB' },
    async (request) => {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'Sign in required');
      }
      await assertPanelAdmin(db, request.auth.uid);

      const text = `${request.data?.text || ''}`.trim();
      const messageType = normalizeFloatingMessageType(request.data?.messageType);
      if (text.length > MAX_TEXT) {
        throw new HttpsError('invalid-argument', 'Mensagem muito longa.');
      }

      const targeting = request.data?.targeting || { type: 'all' };
      const rawActionUrl = `${request.data?.actionUrl || ''}`.trim();
      if (rawActionUrl && !normalizeActionUrl(rawActionUrl)) {
        throw new HttpsError(
          'invalid-argument',
          'actionUrl deve usar https:// (http não permitido).',
        );
      }
      const actionUrl = normalizeActionUrl(rawActionUrl);
      const actionButtonLabel = normalizeActionButtonLabel(
        request.data?.actionButtonLabel,
      );
      let actionRoute = `${request.data?.actionRoute || ''}`.trim() || null;
      if (actionRoute && !actionRoute.startsWith('/')) {
        throw new HttpsError('invalid-argument', 'actionRoute deve começar com /');
      }
      if (actionUrl && actionRoute) {
        throw new HttpsError(
          'invalid-argument',
          'Use apenas actionUrl ou actionRoute, não ambos.',
        );
      }

      const uids = await resolveTargetUids(db, targeting);
      if (!uids.length) {
        throw new HttpsError('failed-precondition', 'Nenhum usuário no público selecionado.');
      }

      const campaignRef = db.collection('admin_broadcasts').doc();
      let imageUrl = normalizeImageUrl(request.data?.imageUrl);
      if (!imageUrl && request.data?.imageBase64) {
        imageUrl = await uploadBroadcastImage(
          admin,
          bucket,
          campaignRef.id,
          request.data?.imageBase64,
        );
      }
      if (!text && !imageUrl) {
        throw new HttpsError('invalid-argument', 'Informe mensagem e/ou imagem.');
      }
      if (messageType === 'promo_banner' && !imageUrl) {
        throw new HttpsError(
          'invalid-argument',
          'promo_banner exige imageUrl ou upload de imagem.',
        );
      }

      const title = `${request.data?.title || ''}`.trim() || 'Novidade no FaceBaby';
      const priority = Math.min(
        100,
        Math.max(0, Number(request.data?.priority) || 10),
      );
      const targetAudience = normalizeFloatingTargetAudience(
        request.data?.targetAudience,
      );
      const dismissMode = normalizeFloatingDismissMode(request.data?.dismissMode);
      const critical = request.data?.critical === true;
      const imageAlt = `${request.data?.imageAlt || ''}`.trim() || null;
      const aspectRaw = Number(request.data?.imageAspectRatio);
      const imageAspectRatio =
        Number.isFinite(aspectRaw) && aspectRaw > 0.2 && aspectRaw < 4
          ? aspectRaw
          : null;
      const startsAt = parseOptionalIsoDate(request.data?.startsAt);
      const endsAt = parseOptionalIsoDate(request.data?.endsAt);

      await campaignRef.set({
        text,
        title,
        messageType,
        priority,
        targetAudience,
        imageUrl: imageUrl || null,
        actionUrl,
        actionButtonLabel,
        actionRoute,
        targeting,
        recipientCount: uids.length,
        status: 'active',
        createdBy: request.auth.uid,
        createdAt: FieldValue.serverTimestamp(),
      });

      await db.collection('floating_messages').doc(campaignRef.id).set({
        title,
        message: text,
        type: messageType,
        active: true,
        priority,
        startsAt: startsAt || FieldValue.serverTimestamp(),
        endsAt: endsAt || null,
        actionLabel: actionButtonLabel || null,
        actionRoute,
        actionUrl: actionUrl || null,
        imageUrl: imageUrl || null,
        imageAlt,
        imageAspectRatio,
        targetAudience,
        dismissMode,
        critical,
        campaignId: campaignRef.id,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      const payload = {
        text,
        imageUrl: imageUrl || null,
        actionUrl,
        actionButtonLabel,
        campaignId: campaignRef.id,
        createdAt: FieldValue.serverTimestamp(),
      };

      for (let i = 0; i < uids.length; i += BATCH_SIZE) {
        const chunk = uids.slice(i, i + BATCH_SIZE);
        const batch = db.batch();
        for (const uid of chunk) {
          const ref = db
            .collection('users')
            .doc(uid)
            .collection('inbox_broadcasts')
            .doc(campaignRef.id);
          batch.set(ref, payload, { merge: true });
        }
        await batch.commit();
      }

      return {
        campaignId: campaignRef.id,
        recipientCount: uids.length,
        imageUrl: imageUrl || null,
      };
    },
  );

  return { previewAdminBroadcastAudience, publishAdminBroadcast };
}

module.exports = { createAdminBroadcastHandlers, resolveTargetUids, userCountryCode };
