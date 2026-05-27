import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../models/ai/ai_nanny_system_context.dart';
import '../../models/ai/voice_record_interpretation.dart';
import 'ai_nanny_orchestrator.dart';
import 'ai_nanny_structured_clarification.dart';
import 'breastfeeding_both_helper.dart';
import 'detected_record_builder.dart';

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
      case 'sleep':
        return _sleep(r);
      default:
        return null;
    }
  }

  static VoiceRecordInterpretation? _sleep(AiNannyStructuredRecord r) {
    final action = '${r.fields['action'] ?? 'start'}';
    DateTime? startedAt;
    final startedRaw = r.fields['startedAt'];
    if (startedRaw is String && startedRaw.isNotEmpty) {
      startedAt = DateTime.tryParse(startedRaw);
    }
    final mins = (r.fields['durationMinutes'] as num?)?.toInt();
    final now = DateTime.now();
    return VoiceRecordInterpretation(
      type: 'sleep',
      summary: 'Sono',
      sleep: VoiceSleepPayload(
        action: action,
        startedAt: startedAt ?? now,
        endedAt: action == 'end' ? now : null,
        durationMinutes: mins,
      ),
    );
  }

  /// Reconstrói um card após resposta de follow-up.
  static AiNannyRecordDraft draftFromRecord(
    AiNannyStructuredRecord rec, {
    required S strings,
    String? sourceText,
    double? lastWeightKg,
    double? lastHeightCm,
  }) {
    return _draftFor(
      rec,
      strings: strings,
      sourceText: sourceText,
      lastWeightKg: lastWeightKg,
      lastHeightCm: lastHeightCm,
    );
  }

  static AiNannyRecordsBundle buildBundle({
    required AiNannyParseResult parse,
    required String userMessage,
    required S strings,
    double? lastWeightKg,
    double? lastHeightCm,
    bool usedExtractionFallback = false,
  }) {
    final drafts = <AiNannyRecordDraft>[];
    for (final rec in parse.records) {
      drafts.add(
        _draftFor(
          rec,
          strings: strings,
          sourceText: userMessage,
          lastWeightKg: lastWeightKg,
          lastHeightCm: lastHeightCm,
        ),
      );
    }
    return prepareBundle(
      bundle: AiNannyRecordsBundle(
        drafts: drafts,
        userMessage: userMessage,
        followUpQuestions: const [],
        usedExtractionFallback: usedExtractionFallback,
      ),
      strings: strings,
      lastWeightKg: lastWeightKg,
      lastHeightCm: lastHeightCm,
    );
  }

  /// Reaplica [enforce], títulos e follow-ups — nunca devolve bundle sem pergunta se incompleto.
  static AiNannyRecordsBundle prepareBundle({
    required AiNannyRecordsBundle bundle,
    required S strings,
    double? lastWeightKg,
    double? lastHeightCm,
    AiNannySystemContext? systemContext,
  }) {
    var drafts = <AiNannyRecordDraft>[];
    for (final d in bundle.drafts) {
      final enforced = AiNannyStructuredClarification.enforce(
        d.structured,
        bundle.userMessage,
        systemContext: systemContext,
      );
      drafts.add(
        draftFromRecord(
          enforced,
          strings: strings,
          sourceText: bundle.userMessage,
          lastWeightKg: lastWeightKg,
          lastHeightCm: lastHeightCm,
        ),
      );
    }
    drafts = BreastfeedingBothHelper.expandDrafts(
      drafts,
      strings: strings,
      sourceText: bundle.userMessage,
      lastWeightKg: lastWeightKg,
      lastHeightCm: lastHeightCm,
    );
    var followUps = DetectedRecordBuilder.followUpsForBundle(drafts, strings);
    if (followUps.isEmpty) {
      for (var i = 0; i < drafts.length; i++) {
        final rec = drafts[i].structured;
        if (rec.missingFields.isEmpty) continue;
        final q = DetectedRecordBuilder.firstFollowUpForRecord(rec, i, strings);
        if (q != null) followUps.add(q);
      }
    }
    followUps = AiNannyOrchestrator.filterFollowUps(followUps, drafts);
    return AiNannyRecordsBundle(
      drafts: drafts,
      userMessage: bundle.userMessage,
      followUpQuestions: followUps,
      usedExtractionFallback: bundle.usedExtractionFallback,
    );
  }

  static AiNannyRecordDraft _finalize(
    AiNannyRecordDraft base,
    AiNannyStructuredRecord rec,
    S strings,
  ) {
    final detected = DetectedRecordBuilder.fromStructured(rec, strings);
    final AiNannyRecordDraftStatus status;
    if (base.status == AiNannyRecordDraftStatus.needsConfirm) {
      status = AiNannyRecordDraftStatus.needsConfirm;
    } else if (rec.missingFields.isNotEmpty ||
        base.status == AiNannyRecordDraftStatus.incomplete) {
      status = AiNannyRecordDraftStatus.incomplete;
    } else {
      status = AiNannyRecordDraftStatus.complete;
    }
    return AiNannyRecordDraft(
      structured: rec,
      status: status,
      displayLine: base.displayLine,
      title: base.title,
      detailLines: [...detected.understoodLines, ...detected.missingLines],
      understoodLines: detected.understoodLines,
      missingLines: detected.missingLines,
      followUpQuestion: base.followUpQuestion,
      detected: detected,
      growthPreview: base.growthPreview,
    );
  }

  static AiNannyRecordDraft _draftFor(
    AiNannyStructuredRecord rec, {
    required S strings,
    String? sourceText,
    double? lastWeightKg,
    double? lastHeightCm,
  }) {
    final missing = rec.missingFields;
    final title = AiNannyStructuredClarification.recordTitle(
      rec,
      strings,
      sourceText: sourceText,
    );
    final details = AiNannyStructuredClarification.detailLines(rec, strings);
    final followUp = AiNannyStructuredClarification.followUpQuestion(rec, strings);
    if (missing.isNotEmpty) {
      return _finalize(
        AiNannyRecordDraft(
          structured: rec,
          status: AiNannyRecordDraftStatus.incomplete,
          displayLine: _displayLine(rec, strings),
          title: title,
          detailLines: details,
          followUpQuestion: followUp,
        ),
        rec,
        strings,
      );
    }

    if (rec.type == 'growth_weight' && rec.fields['mode'] == 'delta') {
      final grams = (rec.fields['value'] as num?)?.toInt() ?? 0;
      final prev = lastWeightKg ?? 0;
      if (prev <= 0) {
        return _finalize(
          AiNannyRecordDraft(
            structured: rec,
            status: AiNannyRecordDraftStatus.incomplete,
            displayLine: strings.aiGrowthNeedBaselineWeight,
            title: title,
            detailLines: details,
            followUpQuestion: followUp,
          ),
          rec,
          strings,
        );
      }
      final next = prev + grams / 1000.0;
      return _finalize(
        AiNannyRecordDraft(
          structured: rec,
          status: AiNannyRecordDraftStatus.needsConfirm,
          displayLine: strings.aiGrowthWeightDeltaPreview(prev, next),
          title: title,
          detailLines: details,
          followUpQuestion: followUp,
          growthPreview: AiNannyGrowthPreview(
          measurementType: 'weight',
          previousValue: prev,
          newValue: next,
          unitLabel: 'kg',
        ),
        ),
        rec,
        strings,
      );
    }

    if (rec.type == 'growth_height' && rec.fields['mode'] == 'delta') {
      final delta = (rec.fields['value'] as num?)?.toDouble() ?? 0;
      final prev = lastHeightCm ?? 0;
      if (prev <= 0) {
        return _finalize(
          AiNannyRecordDraft(
            structured: rec,
            status: AiNannyRecordDraftStatus.incomplete,
            displayLine: strings.aiGrowthNeedBaselineHeight,
            title: title,
            detailLines: details,
            followUpQuestion: followUp,
          ),
          rec,
          strings,
        );
      }
      final next = prev + delta;
      return _finalize(
        AiNannyRecordDraft(
          structured: rec,
          status: AiNannyRecordDraftStatus.needsConfirm,
          displayLine: strings.aiGrowthHeightDeltaPreview(prev, next),
          title: title,
          detailLines: details,
          followUpQuestion: followUp,
          growthPreview: AiNannyGrowthPreview(
            measurementType: 'height',
            previousValue: prev,
            newValue: next,
            unitLabel: 'cm',
          ),
        ),
        rec,
        strings,
      );
    }

    return _finalize(
      AiNannyRecordDraft(
        structured: rec,
        status: AiNannyRecordDraftStatus.complete,
        displayLine: _displayLine(rec, strings),
        title: title,
        detailLines: details,
        followUpQuestion: followUp,
      ),
      rec,
      strings,
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
        final sp = '${r.fields['reasonOrSpecialty'] ?? ''}'.trim();
        final label = sp.isEmpty ? 'Consulta' : sp;
        final date = '${r.fields['date'] ?? ''}'.trim();
        final time = '${r.fields['time'] ?? ''}'.trim();
        if (date.isEmpty) return label;
        if (time.isNotEmpty && time != 'now') return '$label · $date $time';
        return '$label · $date';
      case 'sleep':
        final action = '${r.fields['action'] ?? ''}';
        final mins = r.fields['durationMinutes'];
        final clock = '${r.fields['time'] ?? ''}'.trim();
        if (action == 'end' || r.fields['sleepStatus'] == 'woke') {
          return mins != null
              ? '${strings.aiRecordLabelSleep} · ${strings.aiRecordLineSleepEnd} · $mins min'
              : strings.aiRecordLabelSleep;
        }
        if (mins != null) {
          final buf = StringBuffer('${strings.aiRecordLabelSleep} · $mins min');
          if (clock.isNotEmpty && clock != 'now') buf.write(' · $clock');
          return buf.toString();
        }
        if (clock.isNotEmpty && clock != 'now') {
          return '${strings.aiRecordLabelSleep} · $clock';
        }
        return strings.aiRecordLabelSleep;
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
        return null;
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
    final feverReported = r.fields['feverReported'] == true;
    final feverFromSymptoms = syms is List &&
        syms.any((s) {
          final t = '$s'.toLowerCase();
          return t.contains('fever') || t.contains('temperature');
        });
    final hasFever = feverReported ||
        feverFromSymptoms ||
        (temp != null && temp >= 37.5);
    return VoiceRecordInterpretation(
      type: 'symptom',
      summary: hasFever ? 'Febre' : 'Sintoma',
      symptom: VoiceSymptomPayload(
        fever: hasFever,
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
    DateTime? appliedAt;
    if (status == 'taken') {
      final dateStr = '${r.fields['date'] ?? ''}'.trim();
      appliedAt = DateTime.tryParse(dateStr) ?? now;
      if (dateStr.length <= 10) {
        appliedAt = DateTime(
          appliedAt.year,
          appliedAt.month,
          appliedAt.day,
          now.hour,
          now.minute,
        );
      }
    }
    DateTime? nextDueAt;
    final nextDueStr = '${r.fields['nextDueDate'] ?? ''}'.trim();
    if (nextDueStr.isNotEmpty) {
      final parsed = DateTime.tryParse(nextDueStr);
      if (parsed != null) {
        nextDueAt = DateTime(parsed.year, parsed.month, parsed.day, 9, 0);
      }
    }
    final nextDays = (r.fields['nextDueInDays'] as num?)?.toInt();
    if (nextDueAt == null && nextDays != null && nextDays > 0) {
      final base = DateTime(now.year, now.month, now.day);
      nextDueAt = base.add(Duration(days: nextDays));
    }
    if (status == 'scheduled' && nextDueAt == null) {
      final sched = '${r.fields['date'] ?? ''}'.trim();
      nextDueAt = DateTime.tryParse(sched) ??
          now.add(const Duration(days: 7));
    }
    return VoiceRecordInterpretation(
      type: 'vaccine',
      summary: nextDueAt != null
          ? 'Vacina $name (próxima ${nextDueAt.day.toString().padLeft(2, '0')}/'
              '${nextDueAt.month.toString().padLeft(2, '0')})'
          : 'Vacina $name',
      vaccine: VoiceVaccinePayload(
        name: name,
        dose: r.fields['dose'] as String?,
        appliedAt: appliedAt,
        nextDueAt: nextDueAt,
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
    final date = '${r.fields['date'] ?? ''}'.trim();
    final time = '${r.fields['time'] ?? ''}'.trim();
    final now = DateTime.now();
    var base = DateTime(now.year, now.month, now.day);

    if (date == 'tomorrow') {
      base = base.add(const Duration(days: 1));
    } else if (date == 'today') {
      // keep today
    } else if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      final parsed = DateTime.tryParse(date);
      if (parsed != null) {
        base = DateTime(parsed.year, parsed.month, parsed.day);
      }
    } else if (date == 'next_monday') {
      var diff = DateTime.monday - base.weekday;
      if (diff <= 0) diff += 7;
      base = base.add(Duration(days: diff));
    }

    if (time.contains(':')) {
      final parts = time.split(':');
      final h = int.tryParse(parts[0]) ?? 9;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      return DateTime(base.year, base.month, base.day, h, m);
    }
    // Consulta agendada sem hora → 09:00 no dia indicado.
    return DateTime(base.year, base.month, base.day, 9, 0);
  }
}
