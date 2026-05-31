/** Classificação rápida de perguntas off-topic (sem OpenAI). */

const BABY_CONTEXT_RE =
  /\b(beb[eê]|beb[eê]s|nen[eé]m|filh[oa]s?|filhinho|mam[aeã]|mamar|amament|peito|frald|sono|dormir|dorme|dormindo|pediatr|vacina|consulta|peso|altura|crescimento|refluxo|c[oó]lica|febre|assadur|leite|papai|mam[ãa]e|gesta|gestante|gestacao|gestacional|gravidez|gravida|gravidas|gravid|prenatal|pre.?natal|trimestre|puerp[eé]rio|parto|cesarea|cesariana|obstetr|ginecolog|ultrassom|ecografia|enjoo|utero|utero|placenta|contra[cç][aã]o|beb[eê].?a.?caminho|embaraz|embarazo|pregnant|pregnancy|grossesse|enceinte|schwanger|schwangerschaft|gravidanza|incinta|rec[eé]m.?nascid|salto|desenvolvimento|crianc[aã]|infancia|educa|escola|alfabetiz|disciplina|aprendiz|brincadeir|bercario|maternal|creche|parental|paternidade|maternidade|criar.?filhos|limites|rotina.?escolar|comportamento.?infantil|enxoval)\b/i;

const PREGNANCY_HEALTH_RE =
  /\b(rem[eé]dio|medicamento|vitamina|[aá]cido.?folico|paracetamol|dipirona|ibuprofeno|exerc[ií]cio|alimenta|dieta|suplemento)\b.*\b(gr[aá]vida|gestante|gestacao|gravidez|embarazo|pregnant)\b|\b(gr[aá]vida|gestante|gestacao|gravidez|embarazo|pregnant)\b.*\b(rem[eé]dio|medicamento|vitamina|[aá]cido.?folico|paracetamol|dipirona|ibuprofeno|exerc[ií]cio|alimenta|dieta|suplemento)\b/i;

const INFANT_HEALTH_OTC_RE =
  /\b(paracetamol|dipirona|ibuprofeno|rem[eé]dio|medicamento|antibi[oó]tic)\b.*\b(infantil|beb[eê]|crian[cç]a|gr[aá]vida|gestante)\b|\b(infantil|beb[eê]|crian[cç]a|gr[aá]vida|gestante)\b.*\b(paracetamol|dipirona|ibuprofeno|rem[eé]dio|medicamento)\b/i;

const OFF_TOPIC_RE =
  /\b(pol[ií]tic|elei[cç][aã]o|presidente|deputad|senador|votar|partido|congresso|cinema|filme|s[eé]rie|netflix|novela|futebol|campeonato|bitcoin|criptomoeda|a[cç][oõ]es bolsa|receita culin[aá]ria|restaurante|viagem tur[ií]stic|celebridade|fofoca|hor[oó]scopo pessoal(?!.*beb)|signo (?!.*beb))\b/i;

const REFUSAL_BY_LOCALE = {
  pt:
    'Sou a IA Babá do FaceBaby 💜 Só consigo ajudar com gestação, bebê, crianças, educação infantil, rotina, maternidade/paternidade e saúde infantil. Reformule a pergunta nesse sentido?',
  en:
    "I'm FaceBaby's AI Nanny 💜 I can only help with pregnancy, baby, children, child education, daily care, parenting, and common child health. Please ask again in that context.",
  es:
    'Soy la IA Niñera de FaceBaby 💜 Solo puedo ayudar con embarazo, bebé, niños, educación infantil, rutina, maternidad/paternidad y salud infantil. ¿Puedes reformular la pregunta?',
  fr:
    "Je suis l'IA Nounou FaceBaby 💜 Je ne peux aider qu'avec grossesse, bébé, enfants, éducation infantile, routine, parentalité et santé infantile. Reformulez votre question.",
  de:
    'Ich bin die KI-Babysitterin von FaceBaby 💜 Ich helfe nur bei Schwangerschaft, Baby, Kindern, Kindererziehung, Routine, Elternschaft und Kindergesundheit. Bitte formulieren Sie die Frage neu.',
  it:
    'Sono la IA Tata di FaceBaby 💜 Posso aiutare solo con gravidanza, bebè, bambini, educazione infantile, routine, genitorialità e salute infantile. Riformula la domanda.',
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
