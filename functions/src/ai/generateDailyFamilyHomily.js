const { FieldValue } = require('firebase-admin/firestore');
const { DateTime } = require('luxon');
const { chatCompletion } = require('./openAiClient');
const {
  FAMILY_HOMILY_SYSTEM,
  buildFamilyHomilyUserPrompt,
} = require('./prompts/familyHomilyPrompt');

const SP = 'America/Sao_Paulo';

function languageLabelFromCode(code) {
  const c = `${code || ''}`.trim().toLowerCase();
  const map = {
    pt: 'português do Brasil',
    en: 'English',
    es: 'español',
    fr: 'français',
    de: 'Deutsch',
    it: 'italiano',
  };
  return map[c] || map.pt;
}

function createGenerateDailyFamilyHomily({ onCall, HttpsError, db, openAiApiKey }) {
  return onCall(
    {
      region: 'southamerica-east1',
      secrets: [openAiApiKey],
      timeoutSeconds: 120,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Faça login para ver a homilia.');
      }

      const uid = request.auth.uid;
      const forceRefresh = request.data?.forceRefresh === true;
      const langCode = `${request.data?.languageCode || request.data?.lang || 'pt'}`.trim();

      const userRef = db.collection('users').doc(uid);
      const userSnap = await userRef.get();
      const user = userSnap.data() || {};

      if (user.premiumLifetime !== true) {
        throw new HttpsError(
          'permission-denied',
          'Homilia diária disponível no plano Premium.',
        );
      }

      const nowSp = DateTime.now().setZone(SP);
      const dateKey = nowSp.toFormat('yyyyMMdd');
      const dailyRef = db
        .collection('family_homilies')
        .doc(uid)
        .collection('daily')
        .doc(dateKey);

      if (!forceRefresh) {
        const cached = await dailyRef.get();
        if (cached.exists) {
          const data = cached.data();
          return { ...data, cached: true, dateKey };
        }
      }

      const client = request.data?.profile || {};
      const motherName = `${client.motherName || user.name || user.mother_name || 'Mamãe'}`.trim();
      const babyName = `${client.babyName || 'Bebê'}`.trim() || 'Bebê';

      const apiKey = openAiApiKey.value();
      if (!apiKey) {
        throw new HttpsError('failed-precondition', 'IA temporariamente indisponível.');
      }

      const dateLabel = nowSp.toFormat('dd/MM/yyyy');
      const isoDate = nowSp.toISODate();
      const userPrompt = buildFamilyHomilyUserPrompt({
        dateLabel,
        isoDate,
        motherName,
        babyName,
        languageLabel: languageLabelFromCode(langCode),
      });

      let parsed;
      try {
        const result = await chatCompletion({
          apiKey,
          system: FAMILY_HOMILY_SYSTEM,
          user: userPrompt,
          maxTokens: 1100,
        });
        const raw = result.text.replace(/^```json\s*/i, '').replace(/```\s*$/i, '');
        parsed = JSON.parse(raw);
      } catch (e) {
        throw new HttpsError('internal', 'Não foi possível gerar a homilia agora.');
      }

      const doc = {
        dateKey,
        liturgicalDay: `${parsed.liturgicalDay || ''}`.trim(),
        feastOrMemorial: `${parsed.feastOrMemorial || ''}`.trim(),
        gospelReference: `${parsed.gospelReference || ''}`.trim(),
        homilyText: `${parsed.homilyText || ''}`.trim(),
        familyReflection: `${parsed.familyReflection || ''}`.trim(),
        languageCode: langCode || 'pt',
        createdAt: FieldValue.serverTimestamp(),
        generatedByAi: true,
        cached: false,
      };

      if (!doc.homilyText) {
        throw new HttpsError('internal', 'Não foi possível gerar a homilia agora.');
      }

      await dailyRef.set(doc, { merge: true });
      return doc;
    },
  );
}

module.exports = { createGenerateDailyFamilyHomily };
