const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore } = require('firebase-admin/firestore');
const {
  deleteAllAiChatMessages,
  deleteAiChatMessageDoc,
  trimAiChatHistory,
} = require('./aiChatRetention');

/**
 * Gerencia histórico do chat IA Babá: apagar conversa ou uma troca.
 * action: "clear" | "delete" | "trim"
 */
exports.manageAiNannyChat = onCall(
  {
    region: 'southamerica-east1',
    timeoutSeconds: 120,
    memory: '512MiB',
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Faça login para gerenciar o chat.');
    }

    const uid = request.auth.uid;
    const action = `${request.data?.action || ''}`.trim().toLowerCase();
    const messageId = `${request.data?.messageId || ''}`.trim();
    const db = getFirestore();

    try {
      if (action === 'clear') {
        const result = await deleteAllAiChatMessages(db, uid);
        return { ok: true, action, deleted: result.deleted };
      }

      if (action === 'delete') {
        if (!messageId) {
          throw new HttpsError('invalid-argument', 'messageId obrigatório.');
        }
        const result = await deleteAiChatMessageDoc(db, uid, messageId);
        return { ok: true, action, ...result };
      }

      if (action === 'trim') {
        const result = await trimAiChatHistory(db, uid);
        return { ok: true, action, ...result };
      }

      throw new HttpsError(
        'invalid-argument',
        'Ação inválida. Use clear, delete ou trim.',
      );
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('manageAiNannyChat error', err);
      throw new HttpsError(
        'internal',
        'Não foi possível atualizar o histórico agora.',
      );
    }
  },
);
