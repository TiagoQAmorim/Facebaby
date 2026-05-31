const { FieldValue } = require('firebase-admin/firestore');
const { DateTime } = require('luxon');
const { signFromProfile, SP } = require('./babyContext');
const {
  normalizeLangCode,
  ensureSharedSignDailyText,
  ensureSharedCompatTexts,
} = require('./familySharedCache');

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
      const langCode = normalizeLangCode(request.data?.languageCode || request.data?.lang);

      const userRef = db.collection('users').doc(uid);
      const userSnap = await userRef.get();
      const user = userSnap.data() || {};

      if (user.premiumLifetime !== true) {
        throw new HttpsError(
          'permission-denied',
          'Horóscopo familiar completo disponível no plano Premium.',
        );
      }

      const nowSp = DateTime.now().setZone(SP);
      const dateKey = nowSp.toFormat('yyyyMMdd');
      const dateLabel = nowSp.toFormat('dd/MM/yyyy');
      const dailyRef = db
        .collection('family_horoscopes')
        .doc(uid)
        .collection('daily')
        .doc(dateKey);

      if (!forceRefresh) {
        const cached = await dailyRef.get();
        if (cached.exists) {
          const data = cached.data();
          if (`${data?.motherText || ''}`.trim()) {
            return { ...data, cached: true, dateKey };
          }
        }
      }

      const client = request.data?.profile || {};

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
      let babySign = signFromProfile({
        birthDate: client.babyBirthDate || null,
        storedSign: client.babyZodiacSign || null,
      });

      if (!babySign && selectedBabyId) {
        const babySnap = await userRef.collection('babies').doc(selectedBabyId).get();
        if (babySnap.exists) {
          const baby = babySnap.data() || {};
          babySign = signFromProfile({
            birthDate: baby.birth_date || baby.birthDate,
            storedSign: baby.zodiac_sign || baby.zodiacSign,
          });
        }
      } else if (!babySign) {
        const babiesSnap = await userRef.collection('babies').limit(1).get();
        if (!babiesSnap.empty) {
          const baby = babiesSnap.docs[0].data() || {};
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

      const signLabels = [motherSign, fatherSign, babySign].filter(Boolean);

      let motherText = '';
      let fatherText = '';
      let babyText = '';

      if (motherSign) {
        motherText = await ensureSharedSignDailyText({
          db,
          apiKey,
          langCode,
          dateKey,
          dateLabel,
          signLabel: motherSign,
        });
      }
      if (fatherSign) {
        fatherText = await ensureSharedSignDailyText({
          db,
          apiKey,
          langCode,
          dateKey,
          dateLabel,
          signLabel: fatherSign,
        });
      }
      if (babySign) {
        babyText = await ensureSharedSignDailyText({
          db,
          apiKey,
          langCode,
          dateKey,
          dateLabel,
          signLabel: babySign,
        });
      }

      const { familyCompatibilityText, familyAdviceText } =
        await ensureSharedCompatTexts({
          db,
          apiKey,
          langCode,
          dateKey,
          dateLabel,
          signLabels,
        });

      const doc = {
        dateKey,
        languageCode: langCode,
        motherSign: motherSign || '',
        fatherSign: fatherSign || '',
        babySign: babySign || '',
        motherText,
        fatherText,
        babyText,
        familyCompatibilityText,
        familyAdviceText,
        createdAt: FieldValue.serverTimestamp(),
        generatedByAi: true,
        cached: false,
        sharedBySign: true,
      };

      await dailyRef.set(doc, { merge: true });
      return doc;
    },
  );
}

module.exports = { createGenerateDailyFamilyHoroscope };
