const { DateTime } = require('luxon');



const SP = 'America/Sao_Paulo';



function zodiacSignPtBr(date) {

  const m = date.month;

  const d = date.day;

  if ((m === 12 && d >= 22) || (m === 1 && d <= 19)) return 'Capricórnio';

  if ((m === 1 && d >= 20) || (m === 2 && d <= 18)) return 'Aquário';

  if ((m === 2 && d >= 19) || (m === 3 && d <= 20)) return 'Peixes';

  if ((m === 3 && d >= 21) || (m === 4 && d <= 19)) return 'Áries';

  if ((m === 4 && d >= 20) || (m === 5 && d <= 20)) return 'Touro';

  if ((m === 5 && d >= 21) || (m === 6 && d <= 20)) return 'Gêmeos';

  if ((m === 6 && d >= 21) || (m === 7 && d <= 22)) return 'Câncer';

  if ((m === 7 && d >= 23) || (m === 8 && d <= 22)) return 'Leão';

  if ((m === 8 && d >= 23) || (m === 9 && d <= 22)) return 'Virgem';

  if ((m === 9 && d >= 23) || (m === 10 && d <= 22)) return 'Libra';

  if ((m === 10 && d >= 23) || (m === 11 && d <= 21)) return 'Escorpião';

  return 'Sagitário';

}



function ageLabelFromBirth(birthIso) {

  const birth = DateTime.fromISO(birthIso, { zone: SP }).startOf('day');

  if (!birth.isValid) return null;

  const now = DateTime.now().setZone(SP).startOf('day');

  const days = Math.max(0, Math.floor(now.diff(birth, 'days').days));

  if (days < 30) return `${days} dias`;

  const months = Math.floor(days / 30.44);

  if (months < 24) return `${months} meses`;

  const years = Math.floor(months / 12);

  return `${years} ano(s)`;

}



function formatWhen(when) {

  return DateTime.fromJSDate(when, { zone: SP }).toFormat('dd/MM HH:mm');

}



function buildFamilyBlock(user) {

  const motherName = `${user.name || user.mother_name || user.motherName || ''}`.trim();

  const fatherRegistered =

    user.register_father === true ||

    user.registerFather === true ||

    `${user.father_name || user.fatherName || ''}`.trim().length > 0;

  const fatherName = `${user.father_name || user.fatherName || ''}`.trim();



  const lines = [];

  if (motherName) {
    lines.push(`Mãe/cuidadora (quem conversa no chat): ${motherName}`);
  }

  if (fatherRegistered) {

    lines.push(

      fatherName

        ? `Pai no cadastro: ${fatherName} (não usar na saudação — só se perguntarem)`

        : 'Pai cadastrado (não usar na saudação)',

    );

  }

  return lines.length ? lines.join('\n') : 'Família: nomes não cadastrados no perfil.';

}



async function fetchRecentEvents(db, uid, babyId, limit = 12) {

  const snap = await db

    .collection('users')

    .doc(uid)

    .collection('events')

    .where('baby_id', '==', babyId)

    .limit(100)

    .get();



  const rows = [];

  for (const doc of snap.docs) {

    const d = doc.data();

    const t = d.event_time || d.eventTime || d.created_at;

    const when = t?.toDate?.() ?? (t ? new Date(t) : null);

    if (!when || Number.isNaN(when.getTime())) continue;

    rows.push({

      type: `${d.type || ''}`,

      when,

      payload: d,

    });

  }

  rows.sort((a, b) => b.when - a.when);

  return rows.slice(0, limit);

}



function formatFeedingLine(p) {

  const parts = [];

  const ft = `${p.feeding_type || p.feedingType || ''}`.trim();

  if (ft) parts.push(ft);

  const side = `${p.side || ''}`.trim();

  if (side) parts.push(`lado ${side}`);

  const ml = p.quantity_ml ?? p.quantityMl;

  if (ml != null) parts.push(`${ml} ml`);

  const dur = p.duration_sec ?? p.durationSec;

  if (dur != null && dur > 0) parts.push(`${Math.round(dur / 60)} min`);

  const note = `${p.note || ''}`.trim();

  if (note) parts.push(note.slice(0, 40));

  return parts.length ? parts.join(', ') : 'alimentação';

}



function formatSleepLine(p) {

  const dur = p.duration_sec ?? p.durationSec;

  const mins = dur != null && dur > 0 ? `${Math.round(dur / 60)} min` : '';

  const q = `${p.quality || ''}`.trim();

  return [mins, q].filter(Boolean).join(', ') || 'sono';

}



function formatSymptomLine(p) {

  const bits = [];

  if (p.fever === true) {

    const temp = p.temp_celsius ?? p.tempCelsius;

    bits.push(temp != null ? `febre ${temp}°C` : 'febre');

  }

  if (p.crying) bits.push('choro');

  if (p.colic) bits.push('cólica');

  if (p.reflux) bits.push('refluxo');

  const other = `${p.other_note || p.otherNote || ''}`.trim();

  if (other) bits.push(other.slice(0, 50));

  return bits.length ? bits.join(', ') : 'sintoma';

}



function summarizeEvents(events) {

  const sleep = [];

  const feeding = [];

  const diaper = [];

  const growth = [];

  const health = [];

  let lastJournal = '';



  for (const e of events) {

    const label = formatWhen(e.when);

    const p = e.payload || {};

    switch (e.type) {

      case 'sleep':

        sleep.push(`${label} (${formatSleepLine(p)})`);

        break;

      case 'feeding':

        feeding.push(`${label} (${formatFeedingLine(p)})`);

        break;

      case 'diaper': {

        const kind = `${p.kind || ''}`.trim();

        diaper.push(`${label}${kind ? ` (${kind})` : ''}`);

        break;

      }

      case 'growth': {

        const kind = `${p.kind || ''}`.trim();

        const val = p.value;

        growth.push(

          `${label}${kind && val != null ? `: ${kind} ${val}` : ''}`,

        );

        break;

      }

      case 'symptom_report':

        health.push(`${label} sintoma: ${formatSymptomLine(p)}`);

        break;

      case 'consultation': {

        const title = `${p.title || p.name || 'consulta'}`.trim().slice(0, 40);

        health.push(`${label} consulta: ${title}`);

        break;

      }

      case 'vaccine': {

        const title = `${p.title || p.name || 'vacina'}`.trim().slice(0, 40);

        health.push(`${label} vacina: ${title}`);

        break;

      }

      case 'daily_journal': {

        const text = `${p.text || ''}`.trim();

        if (text && !lastJournal) {

          lastJournal = text.length > 120 ? `${text.slice(0, 120)}…` : text;

        }

        break;

      }

      default:

        break;

    }

  }



  const parts = [];

  if (feeding.length) {

    parts.push(`Últimas alimentações: ${feeding.slice(0, 3).join(' | ')}`);

  }

  if (sleep.length) {

    parts.push(`Últimos sonos: ${sleep.slice(0, 3).join(' | ')}`);

  }

  if (diaper.length) {

    parts.push(`Últimas fraldas: ${diaper.slice(0, 2).join(' | ')}`);

  }

  if (growth.length) {

    parts.push(`Medições recentes: ${growth.slice(0, 2).join(' | ')}`);

  }

  if (health.length) {

    parts.push(`Saúde recente: ${health.slice(0, 2).join(' | ')}`);

  }

  if (lastJournal) {

    parts.push(`Diário recente: ${lastJournal}`);

  }

  return parts.join('\n') || 'Sem registros recentes no app (sono, mamada, fralda, etc.).';

}



/** Última medição de crescimento nos eventos (peso ou altura). */

function latestGrowthValueFromEvents(events, kind) {

  let bestVal = null;

  let bestWhen = null;

  for (const e of events) {

    if (`${e.type || ''}` !== 'growth') continue;

    const p = e.payload || {};

    const k = `${p.kind || ''}`.trim().toLowerCase();

    if (k !== kind) continue;

    const when = e.when;

    if (!when || Number.isNaN(when.getTime())) continue;

    const val =

      typeof p.value === 'number' ? p.value : Number(`${p.value ?? ''}`);

    if (!Number.isFinite(val) || val <= 0) continue;

    if (!bestWhen || when > bestWhen) {

      bestWhen = when;

      bestVal = val;

    }

  }

  return bestVal;

}



/**

 * @param {import('firebase-admin/firestore').Firestore} db

 */

async function buildBabyContextBlock(db, uid, babyId) {

  const userRef = db.collection('users').doc(uid);

  const babyRef = userRef.collection('babies').doc(`${babyId}`);

  const [userSnap, babySnap] = await Promise.all([userRef.get(), babyRef.get()]);

  if (!babySnap.exists) {

    return { block: 'Bebê não encontrado.', babyName: 'Bebê' };

  }



  const baby = babySnap.data() || {};

  const user = userSnap.data() || {};

  const name = `${baby.name || user.baby_name || 'Bebê'}`.trim();

  const birthRaw = baby.birth_date || baby.birthDate;

  let birthLabel = '';

  let ageLabel = '';

  let sign = `${baby.zodiac_sign || baby.zodiacSign || ''}`.trim();

  if (birthRaw) {

    const iso = `${birthRaw}`.includes('T') ? `${birthRaw}` : `${birthRaw}T12:00:00`;

    const dt = DateTime.fromISO(iso, { zone: SP });

    if (dt.isValid) {

      birthLabel = dt.toFormat('dd/MM/yyyy');

      ageLabel = ageLabelFromBirth(iso) || '';

      if (!sign) sign = zodiacSignPtBr({ month: dt.month, day: dt.day });

    }

  }



  const sexRaw = `${baby.sex || ''}`.trim().toUpperCase();

  const sex =

    sexRaw === 'M' ? 'menino' : sexRaw === 'F' ? 'menina' : 'não informado';



  const events = await fetchRecentEvents(db, uid, `${babyId}`);

  const latestWeight = latestGrowthValueFromEvents(events, 'weight');

  const latestHeight = latestGrowthValueFromEvents(events, 'height');

  const profileWeight =

    baby.weight_kg ?? baby.weightKg ?? user.weight_kg ?? user.weightKg;

  const profileHeight =

    baby.height_cm ?? baby.heightCm ?? user.height_cm ?? user.heightCm;

  const weight = latestWeight ?? profileWeight;

  const height = latestHeight ?? profileHeight;

  const eventsSummary = summarizeEvents(events);

  const familyBlock = buildFamilyBlock(user);



  const lines = [

    '--- Família no FaceBaby ---',

    familyBlock,

    '',

    '--- Bebê ---',

    `Nome do bebê: ${name}`,

    birthLabel ? `Nascimento: ${birthLabel}` : null,

    ageLabel ? `Idade aproximada: ${ageLabel}` : null,

    `Sexo: ${sex}`,

    sign ? `Signo: ${sign}` : null,

    weight != null

      ? `Peso atual (kg): ${weight}${latestWeight != null ? ' (última medição no app)' : ' (cadastro)'}`

      : null,

    height != null

      ? `Altura atual (cm): ${height}${latestHeight != null ? ' (última medição no app)' : ' (cadastro)'}`

      : null,

    '',

    '--- Rotina registrada no app ---',

    eventsSummary,

  ].filter((x) => x != null);



  return { block: lines.join('\n'), babyName: name };

}



function signFromProfile({ birthDate, storedSign, nameFallback }) {

  const stored = `${storedSign || ''}`.trim();

  if (stored) return stored;

  if (!birthDate) return null;

  const iso = `${birthDate}`.includes('T') ? `${birthDate}` : `${birthDate}T12:00:00`;

  const dt = DateTime.fromISO(iso, { zone: SP });

  if (!dt.isValid) return null;

  return zodiacSignPtBr({ month: dt.month, day: dt.day });

}



module.exports = {

  buildBabyContextBlock,

  buildFamilyBlock,

  signFromProfile,

  zodiacSignPtBr,

  SP,

};


