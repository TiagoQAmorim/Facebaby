const { FieldValue } = require('firebase-admin/firestore');
const { DateTime } = require('luxon');
const { chatCompletion } = require('./openAiClient');
const {
  FAMILY_HOMILY_SYSTEM,
  buildFamilyHomilyUserPrompt,
  HOMILY_MAX_TOKENS,
} = require('./prompts/familyHomilyPrompt');
const {
  languageLabelFromCode,
  normalizeLangCode,
  sharedHomilyRef,
} = require('./familySharedCache');

const SP = 'America/Sao_Paulo';

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
      const langCode = normalizeLangCode(request.data?.languageCode || request.data?.lang);

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
      const sharedRef = sharedHomilyRef(db, langCode, dateKey);

      if (!forceRefresh) {
        const userCached = await dailyRef.get();
        if (userCached.exists) {
          const data = userCached.data();
          if (`${data?.homilyText || ''}`.trim()) {
            return { ...data, cached: true, dateKey, shared: false };
          }
        }
        const sharedCached = await sharedRef.get();
        if (sharedCached.exists) {
          const data = sharedCached.data();
          if (`${data?.homilyText || ''}`.trim()) {
            const copy = { ...data, cached: true, shared: true };
            await dailyRef.set(copy, { merge: true });
            return { ...copy, dateKey };
          }
        }
      }

      const apiKey = openAiApiKey.value();
      if (!apiKey) {
        throw new HttpsError('failed-precondition', 'IA temporariamente indisponível.');
      }

      if (!forceRefresh) {
        const sharedAgain = await sharedRef.get();
        if (sharedAgain.exists && `${sharedAgain.data()?.homilyText || ''}`.trim()) {
          const data = sharedAgain.data();
          await dailyRef.set({ ...data, cached: true, shared: true }, { merge: true });
          return { ...data, cached: true, dateKey, shared: true };
        }
      }

      const dateLabel = nowSp.toFormat('dd/MM/yyyy');
      const isoDate = nowSp.toISODate();
      const userPrompt = buildFamilyHomilyUserPrompt({
        dateLabel,
        isoDate,
        languageLabel: languageLabelFromCode(langCode),
      });

      let parsed;
      try {
        const result = await chatCompletion({
          apiKey,
          system: FAMILY_HOMILY_SYSTEM,
          user: userPrompt,
          maxTokens: HOMILY_MAX_TOKENS,
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
        languageCode: langCode,
        createdAt: FieldValue.serverTimestamp(),
        generatedByAi: true,
        cached: false,
        shared: true,
      };

      if (!doc.homilyText) {
        throw new HttpsError('internal', 'Não foi possível gerar a homilia agora.');
      }

      try {
        await sharedRef.create(doc);
      } catch (e) {
        const existing = await sharedRef.get();
        if (existing.exists) {
          Object.assign(doc, existing.data());
          doc.cached = true;
        } else {
          await sharedRef.set(doc, { merge: true });
        }
      }

      await dailyRef.set({ ...doc, cached: true }, { merge: true });
      return doc;
    },
  );
}

module.exports = { createGenerateDailyFamilyHomily };
