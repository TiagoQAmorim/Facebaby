const { FieldValue } = require('firebase-admin/firestore');

/** Máximo de documentos (pergunta+resposta = 1 doc) antes de podar. */
const MAX_CHAT_DOCUMENTS = 80;

/** Quantidade alvo após poda automática. */
const TARGET_AFTER_TRIM = 60;

const BATCH_SIZE = 400;

function messagesCol(db, uid) {
  return db.collection('ai_chats').doc(uid).collection('messages');
}

/**
 * Remove os documentos mais antigos quando o histórico passa do limite.
 * @returns {Promise<{ deleted: number, remaining: number }>}
 */
async function trimAiChatHistory(db, uid) {
  const colRef = messagesCol(db, uid);
  const snap = await colRef.orderBy('createdAt', 'asc').get();
  const total = snap.size;
  if (total <= MAX_CHAT_DOCUMENTS) {
    return { deleted: 0, remaining: total };
  }

  const deleteCount = total - TARGET_AFTER_TRIM;
  const toDelete = snap.docs.slice(0, deleteCount);
  let deleted = 0;

  for (let i = 0; i < toDelete.length; i += BATCH_SIZE) {
    const chunk = toDelete.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const doc of chunk) {
      batch.delete(doc.ref);
      deleted += 1;
    }
    await batch.commit();
  }

  await db.collection('ai_chats').doc(uid).set(
    {
      lastTrimmedAt: FieldValue.serverTimestamp(),
      messageCount: total - deleted,
    },
    { merge: true },
  );

  return { deleted, remaining: total - deleted };
}

/**
 * Apaga todo o histórico do chat IA Babá do usuário.
 */
async function deleteAllAiChatMessages(db, uid) {
  const colRef = messagesCol(db, uid);
  const snap = await colRef.get();
  let deleted = 0;

  const docs = snap.docs;
  for (let i = 0; i < docs.length; i += BATCH_SIZE) {
    const chunk = docs.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const doc of chunk) {
      batch.delete(doc.ref);
      deleted += 1;
    }
    await batch.commit();
  }

  await db.collection('ai_chats').doc(uid).set(
    {
      clearedAt: FieldValue.serverTimestamp(),
      messageCount: 0,
      lastTrimmedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { deleted };
}

/**
 * Apaga um par pergunta/resposta (um documento em messages).
 */
async function deleteAiChatMessageDoc(db, uid, messageId) {
  const id = `${messageId || ''}`.trim();
  if (!id) {
    throw new Error('messageId ausente.');
  }
  const ref = messagesCol(db, uid).doc(id);
  const snap = await ref.get();
  if (!snap.exists) {
    return { deleted: false };
  }
  await ref.delete();
  return { deleted: true };
}

module.exports = {
  MAX_CHAT_DOCUMENTS,
  TARGET_AFTER_TRIM,
  trimAiChatHistory,
  deleteAllAiChatMessages,
  deleteAiChatMessageDoc,
};
