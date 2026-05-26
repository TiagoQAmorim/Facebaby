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
- vaccine: vaccineName, dose, status (taken|scheduled), date (today|tomorrow|next_monday|YYYY-MM-DD), time (HH:mm)
- appointment: reasonOrSpecialty, phone, address, date, time, notes

Multilingual intent (examples — same JSON):
- Breastfeeding left 10 min: feedingType breastfeeding, breastSide left, durationMinutes 10
- Diaper pee+poop: pee true, poop true
- Temperature 37.5: health_symptom, temperatureCelsius 37.5
- Weight gain 200g: growth_weight mode delta, unit g, value 200
- Schedule vaccine: status scheduled + missingFields if date/name missing

Rules:
- Infer intent semantically; do not require exact words.
- Multiple records in one sentence → multiple objects.
- missingFields: list what is still required to save.
- needsConfirmation: true if any incomplete record or weight/height delta.
- Never confuse fever temperature (35-42) with weight kg.
- Normalize 37,5 and 37.5 to 37.5. Normalize times to 24h HH:mm.`;

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
    extra += `\nLast weight (kg): ${lastWeightKg}`;
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

function normalizeRecord(r) {
  const type = `${r.type || ''}`.trim().toLowerCase();
  const out = {
    type,
    missingFields: Array.isArray(r.missingFields)
      ? r.missingFields.map((x) => `${x}`)
      : [],
    ...r,
  };
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
