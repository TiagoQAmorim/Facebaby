import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../models/ai/voice_record_interpretation.dart';
import '../../utils/voice_record_clarification.dart';

/// Converte registros estruturados em [VoiceRecordInterpretation] + rascunhos para UI.
abstract final class AiNannyStructuredMapper {
  static List<VoiceRecordInterpretation> toInterpretations(
    List<AiNannyStructuredRecord> records,
  ) {
    return records
        .map(toInterpretation)
        .whereType<VoiceRecordInterpretation>()
        .toList();
  }

  static VoiceRecordInterpretation? toInterpretation(
    AiNannyStructuredRecord r,
  ) {
    switch (r.type) {
      case 'diaper':
        return _diaper(r);
      case 'feeding':
        return _feeding(r);
      case 'health_symptom':
        return _symptom(r);
      case 'growth_weight':
        return _weight(r);
      case 'growth_height':
        return _height(r);
      case 'vaccine':
        return _vaccine(r);
      case 'appointment':
        return _appointment(r);
      default:
        return null;
    }
  }

  static AiNannyRecordsBundle buildBundle({
    required AiNannyParseResult parse,
    required String userMessage,
    required S strings,
    double? lastWeightKg,
    double? lastHeightCm,
  }) {
    final drafts = <AiNannyRecordDraft>[];
    for (final rec in parse.records) {
      drafts.add(
        _draftFor(
          rec,
          strings: strings,
          lastWeightKg: lastWeightKg,
          lastHeightCm: lastHeightCm,
        ),
      );
    }
    return AiNannyRecordsBundle(
      drafts: drafts,
      userMessage: userMessage,
    );
  }

  static AiNannyRecordDraft _draftFor(
    AiNannyStructuredRecord rec, {
    required S strings,
    double? lastWeightKg,
    double? lastHeightCm,
  }) {
    final missing = rec.missingFields;
    if (missing.isNotEmpty) {
      return AiNannyRecordDraft(
        structured: rec,
        status: AiNannyRecordDraftStatus.incomplete,
        displayLine: _displayLine(rec, strings),
      );
    }

    if (rec.type == 'growth_weight' && rec.fields['mode'] == 'delta') {
      final grams = (rec.fields['value'] as num?)?.toInt() ?? 0;
      final prev = lastWeightKg ?? 0;
      if (prev <= 0) {
        return AiNannyRecordDraft(
          structured: rec,
          status: AiNannyRecordDraftStatus.incomplete,
          displayLine: strings.aiGrowthNeedBaselineWeight,
        );
      }
      final next = prev + grams / 1000.0;
      return AiNannyRecordDraft(
        structured: rec,
        status: AiNannyRecordDraftStatus.needsConfirm,
        displayLine: strings.aiGrowthWeightDeltaPreview(prev, next),
        growthPreview: AiNannyGrowthPreview(
          measurementType: 'weight',
          previousValue: prev,
          newValue: next,
          unitLabel: 'kg',
        ),
      );
    }

    if (rec.type == 'growth_height' && rec.fields['mode'] == 'delta') {
      final delta = (rec.fields['value'] as num?)?.toDouble() ?? 0;
      final prev = lastHeightCm ?? 0;
      if (prev <= 0) {
        return AiNannyRecordDraft(
          structured: rec,
          status: AiNannyRecordDraftStatus.incomplete,
          displayLine: strings.aiGrowthNeedBaselineHeight,
        );
      }
      final next = prev + delta;
      return AiNannyRecordDraft(
        structured: rec,
        status: AiNannyRecordDraftStatus.needsConfirm,
        displayLine: strings.aiGrowthHeightDeltaPreview(prev, next),
        growthPreview: AiNannyGrowthPreview(
          measurementType: 'height',
          previousValue: prev,
          newValue: next,
          unitLabel: 'cm',
        ),
      );
    }

    return AiNannyRecordDraft(
      structured: rec,
      status: AiNannyRecordDraftStatus.complete,
      displayLine: _displayLine(rec, strings),
    );
  }

  static String _displayLine(AiNannyStructuredRecord r, S strings) {
    switch (r.type) {
      case 'diaper':
        final pee = r.fields['pee'] == true;
        final poop = r.fields['poop'] == true;
        if (pee && poop) return strings.aiRecordLineDiaperBoth;
        if (pee) return strings.aiRecordLineDiaperPee;
        if (poop) return strings.aiRecordLineDiaperPoo;
        return strings.aiRecordLineDiaperGeneric;
      case 'feeding':
        final ft = '${r.fields['feedingType'] ?? ''}';
        final side = '${r.fields['breastSide'] ?? ''}';
        final mins = r.fields['durationMinutes'];
        final ml = r.fields['amountMl'];
        if (ft == 'breastfeeding') {
          final sideLabel = switch (side) {
            'left' => strings.aiClarifyBreastSide.contains('esquerdo')
                ? 'esquerdo'
                : 'left',
            'right' => 'direito',
            'both' => 'ambos',
            _ => '?',
          };
          return '${strings.aiRecordLineFeeding} · $sideLabel'
              '${mins != null ? ' · ${mins} min' : ''}';
        }
        if (ml != null) return '${strings.aiRecordLineFeeding} · ${ml} ml';
        return strings.aiRecordLineFeeding;
      case 'health_symptom':
        final temp = r.fields['temperatureCelsius'];
        if (temp != null) return 'Temperatura ${temp}°C';
        final syms = r.fields['symptoms'];
        if (syms is List && syms.isNotEmpty) return syms.join(', ');
        return strings.aiRecordLineSymptom;
      case 'growth_weight':
        final mode = r.fields['mode'];
        final v = r.fields['value'];
        if (mode == 'delta') return 'Peso +$v g';
        return 'Peso $v kg';
      case 'growth_height':
        final mode = r.fields['mode'];
        final v = r.fields['value'];
        if (mode == 'delta') return 'Altura +$v cm';
        return 'Altura $v cm';
      case 'vaccine':
        final name = r.fields['vaccineName'] ?? '?';
        final st = r.fields['status'];
        return st == 'scheduled' ? 'Vacina $name (agendar)' : 'Vacina $name';
      case 'appointment':
        final sp = r.fields['reasonOrSpecialty'] ?? 'consulta';
        final date = r.fields['date'] ?? '';
        final time = r.fields['time'] ?? '';
        return 'Consulta $sp $date $time'.trim();
      default:
        return r.type;
    }
  }

  static VoiceRecordInterpretation? _diaper(AiNannyStructuredRecord r) {
    final pee = r.fields['pee'] == true;
    final poop = r.fields['poop'] == true;
    String? kind;
    if (pee && poop) {
      kind = 'both';
    } else if (pee) {
      kind = 'pee';
    } else if (poop) {
      kind = 'poo';
    }
    if (kind == null) return null;
    return VoiceRecordInterpretation(
      type: 'diaper',
      summary: 'Fralda',
      diaper: VoiceDiaperPayload(kind: kind, changedAt: DateTime.now()),
    );
  }

  static VoiceRecordInterpretation? _feeding(AiNannyStructuredRecord r) {
    final ft = '${r.fields['feedingType'] ?? ''}'.toLowerCase();
    String subtype;
    switch (ft) {
      case 'breastfeeding':
        subtype = 'peito';
      case 'bottle':
      case 'formula':
      case 'expressed_milk':
        subtype = 'mamadeira';
      default:
        return null;
    }

    String? side;
    final bs = '${r.fields['breastSide'] ?? ''}';
    switch (bs) {
      case 'left':
        side = 'E';
      case 'right':
        side = 'D';
      case 'both':
        side = 'E';
      default:
        side = null;
    }

    final mins = r.fields['durationMinutes'];
    final note = mins != null ? '$mins min' : null;
    final ml = (r.fields['amountMl'] as num?)?.toDouble();

    if (subtype == 'peito' && (side == null || side.isEmpty)) return null;
    if (subtype == 'peito' && mins == null && note == null) return null;

    return VoiceRecordInterpretation(
      type: 'feeding',
      summary: 'Mamada',
      feeding: VoiceFeedingPayload(
        subtype: subtype,
        side: side,
        quantityMl: ml,
        note: note,
        eventTime: DateTime.now(),
      ),
    );
  }

  static VoiceRecordInterpretation? _symptom(AiNannyStructuredRecord r) {
    final temp = (r.fields['temperatureCelsius'] as num?)?.toDouble();
    final syms = r.fields['symptoms'];
    var crying = false;
    var colic = false;
    var reflux = false;
    if (syms is List) {
      for (final s in syms) {
        final t = '$s'.toLowerCase();
        if (t.contains('choro')) crying = true;
        if (t.contains('cólica') || t.contains('colica')) colic = true;
        if (t.contains('refluxo')) reflux = true;
      }
    }
    return VoiceRecordInterpretation(
      type: 'symptom',
      summary: 'Sintoma',
      symptom: VoiceSymptomPayload(
        fever: temp != null && temp >= 37.5,
        tempCelsius: temp,
        occurredAt: DateTime.now(),
        crying: crying,
        colic: colic,
        reflux: reflux,
      ),
    );
  }

  static VoiceRecordInterpretation? _weight(AiNannyStructuredRecord r) {
    final mode = '${r.fields['mode'] ?? 'total'}';
    if (mode == 'delta') {
      final grams = (r.fields['value'] as num?)?.toInt() ?? 0;
      return VoiceRecordInterpretation(
        type: 'weight',
        summary: 'Peso +${grams}g',
        weight: VoiceWeightPayload(weightDeltaGrams: grams.toDouble()),
      );
    }
    final kg = (r.fields['value'] as num?)?.toDouble();
    if (kg == null || kg <= 0) return null;
    return VoiceRecordInterpretation(
      type: 'weight',
      summary: 'Peso $kg kg',
      weight: VoiceWeightPayload(weightKg: kg),
    );
  }

  static VoiceRecordInterpretation? _height(AiNannyStructuredRecord r) {
    final mode = '${r.fields['mode'] ?? 'total'}';
    if (mode == 'delta') {
      final delta = (r.fields['value'] as num?)?.toDouble() ?? 0;
      return VoiceRecordInterpretation(
        type: 'height',
        summary: 'Altura +$delta cm',
        height: VoiceHeightPayload(heightDeltaCm: delta),
      );
    }
    final cm = (r.fields['value'] as num?)?.toDouble();
    if (cm == null || cm <= 0) return null;
    return VoiceRecordInterpretation(
      type: 'height',
      summary: 'Altura $cm cm',
      height: VoiceHeightPayload(heightCm: cm),
    );
  }

  static VoiceRecordInterpretation? _vaccine(AiNannyStructuredRecord r) {
    final name = '${r.fields['vaccineName'] ?? ''}'.trim();
    if (name.isEmpty) return null;
    final status = '${r.fields['status'] ?? 'taken'}';
  final now = DateTime.now();
    return VoiceRecordInterpretation(
      type: 'vaccine',
      summary: 'Vacina $name',
      vaccine: VoiceVaccinePayload(
        name: name,
        appliedAt: status == 'taken' ? now : null,
        nextDueAt: status == 'scheduled' ? now.add(const Duration(days: 7)) : null,
      ),
    );
  }

  static VoiceRecordInterpretation? _appointment(AiNannyStructuredRecord r) {
    final title = '${r.fields['reasonOrSpecialty'] ?? ''}'.trim();
    if (title.isEmpty) return null;
    return VoiceRecordInterpretation(
      type: 'consultation',
      summary: 'Consulta $title',
      consultation: VoiceConsultationPayload(
        title: title,
        occurredAt: _resolveWhen(r),
        address: r.fields['address'] as String?,
        phone: r.fields['phone'] as String?,
        notes: r.fields['notes'] as String?,
      ),
    );
  }

  static DateTime? _resolveWhen(AiNannyStructuredRecord r) {
    final date = '${r.fields['date'] ?? ''}';
    final time = '${r.fields['time'] ?? ''}';
    final now = DateTime.now();
    var base = DateTime(now.year, now.month, now.day);
    if (date == 'tomorrow') {
      base = base.add(const Duration(days: 1));
    }
    if (time.contains(':')) {
      final parts = time.split(':');
      final h = int.tryParse(parts[0]) ?? 12;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      return DateTime(base.year, base.month, base.day, h, m);
    }
    return base;
  }
}
