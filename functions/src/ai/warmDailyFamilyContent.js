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
  sharedSignRef,
  ensureSharedSignDailyText,
} = require('./familySharedCache');

const SP = 'America/Sao_Paulo';
const WARM_LANGS = ['pt', 'en', 'es', 'fr', 'de', 'it'];

const SIGN_SLUGS = [
  'aries',
  'touro',
  'gemeos',
  'cancer',
  'leao',
  'virgem',
  'libra',
  'escorpiao',
  'sagitario',
  'capricornio',
  'aquario',
  'peixes',
];

const SIGN_LABEL_BY_SLUG = {
  aries: 'Áries',
  touro: 'Touro',
  gemeos: 'Gêmeos',
  cancer: 'Câncer',
  leao: 'Leão',
  virgem: 'Virgem',
  libra: 'Libra',
  escorpiao: 'Escorpião',
  sagitario: 'Sagitário',
  capricornio: 'Capricórnio',
  aquario: 'Aquário',
  peixes: 'Peixes',
};

async function ensureSharedHomily(db, apiKey, langCode, dateKey, dateLabel, isoDate) {
  const lang = normalizeLangCode(langCode);
  const ref = sharedHomilyRef(db, lang, dateKey);
  const existing = await ref.get();
  if (existing.exists && `${existing.data()?.homilyText || ''}`.trim()) {
    return { skipped: true };
  }

  const userPrompt = buildFamilyHomilyUserPrompt({
    dateLabel,
    isoDate,
    languageLabel: languageLabelFromCode(lang),
  });

  const result = await chatCompletion({
    apiKey,
    system: FAMILY_HOMILY_SYSTEM,
    user: userPrompt,
    maxTokens: HOMILY_MAX_TOKENS,
  });
  const raw = result.text.replace(/^```json\s*/i, '').replace(/```\s*$/i, '');
  const parsed = JSON.parse(raw);

  const doc = {
    dateKey,
    liturgicalDay: `${parsed.liturgicalDay || ''}`.trim(),
    feastOrMemorial: `${parsed.feastOrMemorial || ''}`.trim(),
    gospelReference: `${parsed.gospelReference || ''}`.trim(),
    homilyText: `${parsed.homilyText || ''}`.trim(),
    familyReflection: `${parsed.familyReflection || ''}`.trim(),
    languageCode: lang,
    createdAt: FieldValue.serverTimestamp(),
    generatedByAi: true,
    cached: false,
    shared: true,
  };

  if (!doc.homilyText) {
    throw new Error('empty_homily');
  }

  try {
    await ref.create(doc);
  } catch (e) {
    const again = await ref.get();
    if (!again.exists) {
      await ref.set(doc, { merge: true });
    }
  }

  return { skipped: false };
}

async function ensureSharedSignWarm(db, apiKey, langCode, dateKey, dateLabel, slug) {
  const lang = normalizeLangCode(langCode);
  const label = SIGN_LABEL_BY_SLUG[slug] || slug;
  const ref = sharedSignRef(db, lang, dateKey, slug);
  const existing = await ref.get();
  if (existing.exists && `${existing.data()?.dailyText || ''}`.trim()) {
    return { skipped: true };
  }

  await ensureSharedSignDailyText({
    db,
    apiKey,
    langCode: lang,
    dateKey,
    dateLabel,
    signLabel: label,
  });
  return { skipped: false };
}

async function runWarmDailyFamilyContent({ db, apiKey }) {
  const nowSp = DateTime.now().setZone(SP);
  const dateKey = nowSp.toFormat('yyyyMMdd');
  const dateLabel = nowSp.toFormat('dd/MM/yyyy');
  const isoDate = nowSp.toISODate();

  const stats = {
    dateKey,
    homilyGenerated: 0,
    homilySkipped: 0,
    signGenerated: 0,
    signSkipped: 0,
    errors: [],
  };

  for (const lang of WARM_LANGS) {
    try {
      const homily = await ensureSharedHomily(
        db,
        apiKey,
        lang,
        dateKey,
        dateLabel,
        isoDate,
      );
      if (homily.skipped) stats.homilySkipped += 1;
      else stats.homilyGenerated += 1;
    } catch (e) {
      stats.errors.push({ lang, type: 'homily', message: `${e.message || e}` });
    }

    for (const slug of SIGN_SLUGS) {
      try {
        const sign = await ensureSharedSignWarm(
          db,
          apiKey,
          lang,
          dateKey,
          dateLabel,
          slug,
        );
        if (sign.skipped) stats.signSkipped += 1;
        else stats.signGenerated += 1;
      } catch (e) {
        stats.errors.push({
          lang,
          slug,
          type: 'sign',
          message: `${e.message || e}`,
        });
      }
    }
  }

  return stats;
}

module.exports = { runWarmDailyFamilyContent, ensureSharedHomily };
