const { DateTime } = require('luxon');

const PARSE_AI_NANNY_SYSTEM = `You extract structured baby-care records for FaceBaby from ONE user message in ANY language (PT-BR, EN, ES, IT, FR, DE).
Reply ONLY with valid JSON (no markdown).

The INPUT language may vary. OUTPUT field values MUST use the canonical English schema below (same JSON in every locale).

classification: "create_records" | "chat_only"

records[] items — types and canonical fields:
- diaper: pee (bool), poop (bool), time ("now" or HH:mm 24h)
- feeding: feedingType (breastfeeding|bottle|formula|expressed_milk|unknown), breastSide (left|right|both), durationMinutes (int), amountMl (int), time
- health_symptom: symptoms (array of English snake tokens e.g. elevated_temperature, crying, colic), temperatureCelsius (number with dot decimal), medicationTaken, medicationName, medicationDose, time
- growth_weight: measurementType "weight", value (number), unit (kg|g), mode (total|delta)
- growth_height: measurementType "height", value, unit "cm", mode (total|delta)
- vaccine: vaccineName, dose, status (taken|scheduled), date (today|tomorrow|next_monday|YYYY-MM-DD), time (HH:mm), nextDueInDays (int), nextDueDate (YYYY-MM-DD)
- appointment: reasonOrSpecialty, phone, address, date (ISO YYYY-MM-DD or today/tomorrow), time (HH:mm optional), notes
- Schedule consultation Friday: appointment reasonOrSpecialty "Consulta" or specialty, date = next Friday ISO, time optional
- sleep: action (start|end|complete), durationMinutes (if "dormiu X minutos"), time ("now" or HH:mm 24h), startedAt optional when duration+time known
- She slept 72 min at 18:03: sleep action complete, durationMinutes 72, time 18:03 — do NOT leave vaccineName-style gaps; never put sleepStatus/startedAt in missingFields if duration is in the message

Multilingual intent (examples — same JSON):
- Breastfeeding left 10 min: feedingType breastfeeding, breastSide left, durationMinutes 10
- Diaper pee+poop: pee true, poop true
- Temperature 37.5: health_symptom, temperatureCelsius 37.5
- Weight gain 200g / engordou 200g / ganhou 200 gramas: growth_weight mode delta, unit g, value 200
- Schedule vaccine: status scheduled + missingFields if date/name missing
- Vaccine taken today: vaccineName "B1" (or exact name user said), status taken, date today ISO — NEVER leave vaccineName empty if user said B1/BCG/etc.
- Vaccine taken today AND "próxima/próximo/daqui a N dias": status taken, date today ISO, nextDueInDays N (and nextDueDate if you can compute). Keep ONE vaccine record with both applied today and next dose date — do NOT drop the reminder.
- Vaccine only scheduled for future (no tomou/aplicou): status scheduled, date or nextDueDate required

Rules:
- Infer intent semantically; do not require exact words (informal speech, slang, broken phrases OK).
- Multiple records in one sentence → multiple objects (e.g. feeding AND diaper = 2 records; "mamou e está com febre" = feeding + health_symptom with fever).
- "acordou/despertou … e cresceu X cm" → sleep action end + growth_height mode delta value X — TWO records, never pick only one.
- "acordou … e ganhou X gramas" → sleep end + growth_weight mode delta — TWO records.
- "está com febre" / "com febre" without number: health_symptom symptoms ["fever"], missingFields ["temperatureCelsius"] — never drop fever when feeding is also present.
- missingFields: list REQUIRED fields still absent — NEVER invent breastSide, amountMl, diaper pee/poop, sleep start time, vaccine date, etc.
- If time is unknown, use "now" in fields AND do NOT mark time as missing (user may edit before save).
- For breastfeeding without side: missingFields must include breastSide. Without duration: include durationMinutes.
- For diaper change without type: missingFields must include pee and/or poop until known.
- For growth_weight / growth_height: missingFields may ONLY include "value" if the number is unknown. NEVER use pee, poop, feedingType, breastSide, or generic "type" for growth records.
- needsConfirmation: true if any incomplete record or weight/height delta.
- classification "chat_only" ONLY when there is zero registrable baby-care event.
- NEGATION / absence (NO records): phrases like "didn't / não / no / sin / pas" + routine action = concern or question only — classification chat_only, records []. Examples (any language): "não fez xixi", "não mamou", "não dormiu", "não cresceu", "não aumentou o peso", "didn't pee", "didn't nurse", "no weight gain", "hasn't slept". NEVER create diaper/feeding/sleep/growth records for negated absence.
- POSITIVE records only when the family reports the baby DID the action (mamou, dormiu, fez xixi, ganhou X g, perdeu X g, cresceu X cm).
- WEIGHT LOSS is registrable: "perdeu 200 gramas", "lost 200g", "emagreceu 150g" → growth_weight mode delta, value NEGATIVE (-200), unit g.
- Never confuse fever temperature (35-42) with weight kg.
- Normalize 37,5 and 37.5 to 37.5. Normalize times to 24h HH:mm.
- Priority: structured extraction over friendly conversation.`;

function buildParseAiNannyUserPrompt({
  message,
  babyName,
  nowIso,
  timezone,
  locale,
  lastWeightKg,
  lastHeightCm,
}) {
  let extra = '';
  if (lastWeightKg != null) {
    extra += `\nCurrent weight baseline (kg) — add deltas to THIS value, not birth weight: ${lastWeightKg}`;
  }
  if (lastHeightCm != null) {
    extra += `\nLast height (cm): ${lastHeightCm}`;
  }
  return `Current locale: ${locale || 'pt_BR'}
Baby: ${babyName || 'Baby'}
Now (${timezone || 'America/Sao_Paulo'}): ${nowIso}
${extra}

User message:
${message}`;
}

function parseAiNannyMessageJson(raw) {
  let text = `${raw || ''}`.trim();
  if (text.startsWith('```')) {
    text = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
  }
  const parsed = JSON.parse(text);
  const records = Array.isArray(parsed.records) ? parsed.records : [];
  return {
    classification: `${parsed.classification || 'chat_only'}`.trim(),
    records: records.map((r) => normalizeRecord(r)),
    needsConfirmation: parsed.needsConfirmation !== false,
  };
}

function canonicalRecordType(type, fields) {
  let t = `${type || ''}`.trim().toLowerCase();
  if (t === 'height' || t === 'altura') return 'growth_height';
  if (t === 'weight' || t === 'peso') return 'growth_weight';
  if (t === 'growth' || t === 'crescimento' || t === 'measurement') {
    const mt = `${fields.measurementType || ''}`.toLowerCase();
    if (mt === 'height' || mt === 'altura') return 'growth_height';
    if (mt === 'weight' || mt === 'peso') return 'growth_weight';
    const unit = `${fields.unit || ''}`.toLowerCase();
    if (unit === 'cm') return 'growth_height';
    if (unit === 'kg' || unit === 'g') return 'growth_weight';
  }
  return t;
}

function sanitizeMissingForType(type, missing) {
  const allowedByType = {
    growth_height: new Set(['value']),
    growth_weight: new Set(['value']),
    diaper: new Set(['pee', 'poop']),
    feeding: new Set(['feedingType', 'breastSide', 'durationMinutes', 'amountMl']),
    sleep: new Set(['startedAt', 'sleepStatus', 'durationMinutes']),
    health_symptom: new Set(['symptoms']),
    vaccine: new Set(['vaccineName', 'date']),
    appointment: new Set(['reasonOrSpecialty', 'date']),
  };
  const allowed = allowedByType[type];
  if (!allowed) {
    return missing.filter((f) => f !== 'type' && f !== 'measurementType');
  }
  return missing.filter((f) => allowed.has(f));
}

function normalizeRecord(r) {
  const rawType = `${r.type || ''}`.trim().toLowerCase();
  const out = {
    type: rawType,
    missingFields: Array.isArray(r.missingFields)
      ? r.missingFields.map((x) => `${x}`)
      : [],
    ...r,
  };
  out.type = canonicalRecordType(out.type, out);
  out.missingFields = sanitizeMissingForType(out.type, out.missingFields);
  if (out.feedingType === 'peito' || out.feedingType === 'breast') {
    out.feedingType = 'breastfeeding';
  }
  if (out.temperatureCelsius != null && typeof out.temperatureCelsius === 'string') {
    out.temperatureCelsius = parseFloat(`${out.temperatureCelsius}`.replace(',', '.'));
  }
  return out;
}

function nowSpIso() {
  return DateTime.now().setZone('America/Sao_Paulo').toISO() || new Date().toISOString();
}

module.exports = {
  PARSE_AI_NANNY_SYSTEM,
  buildParseAiNannyUserPrompt,
  parseAiNannyMessageJson,
  nowSpIso,
};
