/** Classificação rápida de perguntas off-topic (sem OpenAI). */

const BABY_CONTEXT_RE =
  /\b(beb[eê]|beb[eê]s|nen[eé]m|filh[oa]s?|filhinho|mam[aeã]|mamar|amament|peito|frald|sono|dormir|dorme|dormindo|pediatr|vacina|consulta|peso|altura|crescimento|refluxo|c[oó]lica|febre|assadur|leite|papai|pai\b|mam[ãa]e|gesta|gestante|gestacao|gestacional|gravidez|gravida|gravidas|gravid|prenatal|pre.?natal|trimestre|puerp[eé]rio|parto|cesarea|cesariana|obstetr|ginecolog|ultrassom|ecografia|enjoo|utero|utero|placenta|contra[cç][aã]o|beb[eê].?a.?caminho|embaraz|embarazo|pregnant|pregnancy|grossesse|enceinte|schwanger|schwangerschaft|gravidanza|incinta|rec[eé]m.?nascid|salto|desenvolvimento|crianc[aã]|infancia|educa|escola|alfabetiz|disciplina|aprendiz|brincadeir|bercario|maternal|creche|parental|paternidade|maternidade|criar.?filhos|limites|rotina.?escolar|comportamento.?infantil|enxoval|fam[ií]lia|desabaf|ansiedad|ansiedade|depress|culpa|solid[aã]o|solida|burnout|exaust|cansad|sa[uú]de.?mental|emocional|psicol[oó]g|conselh|apoio.?emocional|parceir|relacionamento|casal|triste|medo|insegur|culpad|chorando|sobrecarreg|sozinha|sozinho|cuidador|av[oó]s?)\b/i;

const PREGNANCY_HEALTH_RE =
  /\b(rem[eé]dio|medicamento|vitamina|[aá]cido.?folico|paracetamol|dipirona|ibuprofeno|exerc[ií]cio|alimenta|dieta|suplemento)\b.*\b(gr[aá]vida|gestante|gestacao|gravidez|embarazo|pregnant)\b|\b(gr[aá]vida|gestante|gestacao|gravidez|embarazo|pregnant)\b.*\b(rem[eé]dio|medicamento|vitamina|[aá]cido.?folico|paracetamol|dipirona|ibuprofeno|exerc[ií]cio|alimenta|dieta|suplemento)\b/i;

const INFANT_HEALTH_OTC_RE =
  /\b(paracetamol|dipirona|ibuprofeno|rem[eé]dio|medicamento|antibi[oó]tic)\b.*\b(infantil|beb[eê]|crian[cç]a|gr[aá]vida|gestante)\b|\b(infantil|beb[eê]|crian[cç]a|gr[aá]vida|gestante)\b.*\b(paracetamol|dipirona|ibuprofeno|rem[eé]dio|medicamento)\b/i;

const OFF_TOPIC_RE =
  /\b(pol[ií]tic|elei[cç][aã]o|presidente|deputad|senador|votar|partido|congresso|cinema|filme|s[eé]rie|netflix|novela|futebol|campeonato|bitcoin|criptomoeda|a[cç][oõ]es bolsa|receita culin[aá]ria|restaurante|viagem tur[ií]stic|celebridade|fofoca|hor[oó]scopo pessoal(?!.*beb)|signo (?!.*beb))\b/i;

const REFUSAL_BY_LOCALE = {
  pt:
    'Sou a IA Babá do FaceBaby 💜 Ajudo com gestação, bebê, crianças, rotina, maternidade/paternidade, saúde infantil e apoio emocional da família. Reformule nesse sentido?',
  en:
    "I'm FaceBaby's AI Nanny 💜 I help with pregnancy, baby, children, daily care, parenting, child health, and family emotional support. Please ask again in that context.",
  es:
    'Soy la IA Niñera de FaceBaby 💜 Ayudo con embarazo, bebé, niños, rutina, maternidad/paternidad, salud infantil y apoyo emocional familiar. ¿Reformulas la pregunta?',
  fr:
    "Je suis l'IA Nounou FaceBaby 💜 J'aide avec grossesse, bébé, enfants, routine, parentalité, santé infantile et soutien émotionnel de la famille. Reformulez votre question.",
  de:
    'Ich bin die KI-Babysitterin von FaceBaby 💜 Ich helfe bei Schwangerschaft, Baby, Kindern, Routine, Elternschaft, Kindergesundheit und emotionalem Familiensupport. Bitte Frage neu formulieren.',
  it:
    'Sono la IA Tata di FaceBaby 💜 Aiuto con gravidanza, bebè, bambini, routine, genitorialità, salute infantile e supporto emotivo della famiglia. Riformula la domanda.',
};

function normalizeLocale(locale) {
  const code = `${locale || 'pt'}`.trim().toLowerCase().split(/[-_]/)[0];
  return REFUSAL_BY_LOCALE[code] ? code : 'en';
}

function normalizeQuestion(question) {
  return `${question || ''}`
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}

/**
 * @returns {'allowed' | 'off_topic' | 'unclear'}
 */
function classifyAiNannyQuestion(question) {
  const q = `${question || ''}`.trim();
  if (!q) return 'allowed';

  const qNorm = normalizeQuestion(q);

  if (BABY_CONTEXT_RE.test(qNorm)) return 'allowed';

  if (PREGNANCY_HEALTH_RE.test(qNorm)) return 'allowed';

  if (INFANT_HEALTH_OTC_RE.test(qNorm)) return 'allowed';

  if (OFF_TOPIC_RE.test(qNorm)) return 'off_topic';

  return 'unclear';
}

function offTopicRefusalMessage(locale) {
  const code = normalizeLocale(locale);
  return REFUSAL_BY_LOCALE[code];
}

module.exports = {
  classifyAiNannyQuestion,
  offTopicRefusalMessage,
};
