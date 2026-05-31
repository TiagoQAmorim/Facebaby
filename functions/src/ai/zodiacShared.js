/** Slug estável para signos (PT-BR) — chave de cache compartilhado. */
const SIGN_SLUG_BY_LABEL = {
  capricórnio: 'capricornio',
  capricornio: 'capricornio',
  aquário: 'aquario',
  aquario: 'aquario',
  peixes: 'peixes',
  áries: 'aries',
  aries: 'aries',
  touro: 'touro',
  gêmeos: 'gemeos',
  gemeos: 'gemeos',
  câncer: 'cancer',
  cancer: 'cancer',
  leão: 'leao',
  leao: 'leao',
  virgem: 'virgem',
  libra: 'libra',
  escorpião: 'escorpiao',
  escorpiao: 'escorpiao',
  sagitário: 'sagitario',
  sagitario: 'sagitario',
};

function signSlugFromLabel(signLabel) {
  const raw = `${signLabel || ''}`.trim().toLowerCase();
  if (!raw) return '';
  return SIGN_SLUG_BY_LABEL[raw] || raw.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/\s+/g, '_');
}

/** Chave de combo (signos únicos ordenados) para texto de compatibilidade familiar. */
function familySignComboKey(signs) {
  const slugs = [...new Set(signs.map(signSlugFromLabel).filter(Boolean))].sort();
  return slugs.join('_') || 'unknown';
}

module.exports = { signSlugFromLabel, familySignComboKey, SIGN_SLUG_BY_LABEL };
