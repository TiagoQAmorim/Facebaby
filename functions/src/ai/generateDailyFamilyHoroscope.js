const { FieldValue } = require('firebase-admin/firestore');
const { DateTime } = require('luxon');
const { chatCompletion } = require('./openAiClient');
const {
  FAMILY_HOROSCOPE_SYSTEM,
  buildFamilyHoroscopeUserPrompt,
} = require('./prompts/familyHoroscopePrompt');
const { signFromProfile, SP } = require('./babyContext');

function createGenerateDailyFamilyHoroscope({ onCall, HttpsError, db, openAiApiKey }) {
  return onCall(
    {
      region: 'southamerica-east1',
      secrets: [openAiApiKey],
      timeoutSeconds: 120,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Faça login para ver o horóscopo.');
      }

      const uid = request.auth.uid;
      const forceRefresh = request.data?.forceRefresh === true;

      const userRef = db.collection('users').doc(uid);
      const userSnap = await userRef.get();
      const user = userSnap.data() || {};

      if (user.premiumLifetime !== true) {
        throw new HttpsError(
          'permission-denied',
          'Horóscopo familiar completo disponível no plano Premium.',
        );
      }

      const dateKey = DateTime.now().setZone(SP).toFormat('yyyyMMdd');
      const dailyRef = db
        .collection('family_horoscopes')
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
      const motherSign = signFromProfile({
        birthDate:
          client.motherBirthDate ||
          user.birth_date ||
          user.birthDate,
        storedSign: null,
      });

      const fatherRegistered =
        client.fatherRegistered === true ||
        user.register_father === true ||
        user.registerFather === true ||
        `${client.fatherName || user.father_name || user.fatherName || ''}`.trim().length > 0;

      const fatherName = fatherRegistered
        ? `${client.fatherName || user.father_name || user.fatherName || 'Papai'}`.trim()
        : null;
      const fatherSign = fatherRegistered
        ? signFromProfile({
            birthDate:
              client.fatherBirthDate ||
              user.father_birth_date ||
              user.fatherBirthDate,
            storedSign: null,
          })
        : null;

      const selectedBabyId = `${client.babyId || user.selectedBabyId || user.selected_baby_id || ''}`.trim();
      let babyName = `${client.babyName || 'Bebê'}`.trim() || 'Bebê';
      let babySign = signFromProfile({
        birthDate: client.babyBirthDate || null,
        storedSign: client.babyZodiacSign || null,
      });

      if (!babySign && selectedBabyId) {
        const babySnap = await userRef.collection('babies').doc(selectedBabyId).get();
        if (babySnap.exists) {
          const baby = babySnap.data() || {};
          babyName = `${baby.name || babyName}`.trim();
          babySign = signFromProfile({
            birthDate: baby.birth_date || baby.birthDate,
            storedSign: baby.zodiac_sign || baby.zodiacSign,
          });
        }
      } else if (!babySign) {
        const babiesSnap = await userRef.collection('babies').limit(1).get();
        if (!babiesSnap.empty) {
          const baby = babiesSnap.docs[0].data() || {};
          babyName = `${baby.name || babyName}`.trim();
          babySign = signFromProfile({
            birthDate: baby.birth_date || baby.birthDate,
            storedSign: baby.zodiac_sign || baby.zodiacSign,
          });
        }
      }

      if (!motherSign && !babySign) {
        throw new HttpsError(
          'failed-precondition',
          'Cadastre as datas de nascimento na Família para gerar o horóscopo.',
        );
      }

      const apiKey = openAiApiKey.value();
      if (!apiKey) {
        throw new HttpsError('failed-precondition', 'IA temporariamente indisponível.');
      }

      const dateLabel = DateTime.now().setZone(SP).toFormat('dd/MM/yyyy');
      const userPrompt = buildFamilyHoroscopeUserPrompt({
        dateLabel,
        motherName,
        motherSign: motherSign || 'não informado',
        fatherName,
        fatherSign,
        babyName,
        babySign: babySign || 'não informado',
      });

      let parsed;
      try {
        const result = await chatCompletion({
          apiKey,
          system: FAMILY_HOROSCOPE_SYSTEM,
          user: userPrompt,
          maxTokens: 1200,
        });
        const raw = result.text.replace(/^```json\s*/i, '').replace(/```\s*$/i, '');
        parsed = JSON.parse(raw);
      } catch (e) {
        throw new HttpsError('internal', 'Não foi possível gerar o horóscopo agora.');
      }

      const doc = {
        dateKey,
        motherSign: motherSign || '',
        fatherSign: fatherSign || '',
        babySign: babySign || '',
        motherText: `${parsed.motherText || ''}`.trim(),
        fatherText: `${parsed.fatherText || ''}`.trim(),
        babyText: `${parsed.babyText || ''}`.trim(),
        familyCompatibilityText: `${parsed.familyCompatibilityText || ''}`.trim(),
        familyAdviceText: `${parsed.familyAdviceText || ''}`.trim(),
        createdAt: FieldValue.serverTimestamp(),
        generatedByAi: true,
        cached: false,
      };

      await dailyRef.set(doc, { merge: true });
      return doc;
    },
  );
}

module.exports = { createGenerateDailyFamilyHoroscope };
