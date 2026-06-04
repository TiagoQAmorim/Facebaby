const { FieldValue } = require('firebase-admin/firestore');
const { chatCompletion } = require('./openAiClient');
const {
  FAMILY_HOROSCOPE_SIGN_SYSTEM,
  buildFamilyHoroscopeSignUserPrompt,
} = require('./prompts/familyHoroscopeSignPrompt');
const {
  FAMILY_HOROSCOPE_COMPAT_SYSTEM,
  buildFamilyHoroscopeCompatUserPrompt,
} = require('./prompts/familyHoroscopeCompatPrompt');
const { signSlugFromLabel, familySignComboKey } = require('./zodiacShared');

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

function normalizeLangCode(code) {
  const c = `${code || 'pt'}`.trim().toLowerCase();
  return c || 'pt';
}

function sharedHomilyRef(db, langCode, dateKey) {
  return db
    .collection('family_homilies_shared')
    .doc(normalizeLangCode(langCode))
    .collection('daily')
    .doc(dateKey);
}

function sharedSignRef(db, langCode, dateKey, signSlug) {
  return db
    .collection('family_horoscope_sign_shared')
    .doc(normalizeLangCode(langCode))
    .collection('daily')
    .doc(dateKey)
    .collection('signs')
    .doc(signSlug);
}

function sharedCompatRef(db, langCode, dateKey, comboKey) {
  return db
    .collection('family_horoscope_compat_shared')
    .doc(normalizeLangCode(langCode))
    .collection('daily')
    .doc(dateKey)
    .collection('combos')
    .doc(comboKey);
}

async function ensureSharedSignDailyText({
  db,
  apiKey,
  langCode,
  dateKey,
  dateLabel,
  signLabel,
}) {
  const slug = signSlugFromLabel(signLabel);
  if (!slug) return '';

  const ref = sharedSignRef(db, langCode, dateKey, slug);
  const cached = await ref.get();
  if (cached.exists) {
    const t = `${cached.data()?.dailyText || ''}`.trim();
    if (t) return t;
  }

  const languageLabel = languageLabelFromCode(langCode);
  const userPrompt = buildFamilyHoroscopeSignUserPrompt({
    dateLabel,
    signLabel,
    languageLabel,
  });

  const result = await chatCompletion({
    apiKey,
    system: FAMILY_HOROSCOPE_SIGN_SYSTEM,
    user: userPrompt,
    maxTokens: 280,
  });
  const raw = result.text.replace(/^```json\s*/i, '').replace(/```\s*$/i, '');
  const parsed = JSON.parse(raw);
  const dailyText = `${parsed.dailyText || ''}`.trim();
  if (!dailyText) {
    throw new Error('empty_sign_horoscope');
  }

  const payload = {
    signLabel,
    signSlug: slug,
    dailyText,
    languageCode: normalizeLangCode(langCode),
    dateKey,
    createdAt: FieldValue.serverTimestamp(),
    generatedByAi: true,
  };

  try {
    await ref.create(payload);
  } catch (e) {
    const again = await ref.get();
    const existing = `${again.data()?.dailyText || ''}`.trim();
    if (existing) return existing;
    await ref.set(payload, { merge: true });
  }

  return dailyText;
}

async function ensureSharedCompatTexts({
  db,
  apiKey,
  langCode,
  dateKey,
  dateLabel,
  signLabels,
}) {
  const comboKey = familySignComboKey(signLabels);
  const ref = sharedCompatRef(db, langCode, dateKey, comboKey);
  const cached = await ref.get();
  if (cached.exists) {
    const d = cached.data() || {};
    const compat = `${d.familyCompatibilityText || ''}`.trim();
    const advice = `${d.familyAdviceText || ''}`.trim();
    if (compat || advice) {
      return { familyCompatibilityText: compat, familyAdviceText: advice };
    }
  }

  const signsLabel = signLabels.filter(Boolean).join(', ');
  const userPrompt = buildFamilyHoroscopeCompatUserPrompt({
    dateLabel,
    signsLabel,
    languageLabel: languageLabelFromCode(langCode),
  });

  const result = await chatCompletion({
    apiKey,
    system: FAMILY_HOROSCOPE_COMPAT_SYSTEM,
    user: userPrompt,
    maxTokens: 360,
  });
  const raw = result.text.replace(/^```json\s*/i, '').replace(/```\s*$/i, '');
  const parsed = JSON.parse(raw);
  const familyCompatibilityText = `${parsed.familyCompatibilityText || ''}`.trim();
  const familyAdviceText = `${parsed.familyAdviceText || ''}`.trim();

  const payload = {
    comboKey,
    signLabels,
    familyCompatibilityText,
    familyAdviceText,
    languageCode: normalizeLangCode(langCode),
    dateKey,
    createdAt: FieldValue.serverTimestamp(),
    generatedByAi: true,
  };

  try {
    await ref.create(payload);
  } catch (e) {
    const again = await ref.get();
    if (again.exists) {
      const d = again.data() || {};
      return {
        familyCompatibilityText: `${d.familyCompatibilityText || ''}`.trim(),
        familyAdviceText: `${d.familyAdviceText || ''}`.trim(),
      };
    }
    await ref.set(payload, { merge: true });
  }

  return { familyCompatibilityText, familyAdviceText };
}

module.exports = {
  languageLabelFromCode,
  normalizeLangCode,
  sharedHomilyRef,
  ensureSharedSignDailyText,
  ensureSharedCompatTexts,
};
