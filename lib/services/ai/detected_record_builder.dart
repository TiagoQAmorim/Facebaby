import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../models/ai/detected_baby_record.dart';
import '../../utils/ai_nanny_parse_normalize.dart';
import 'ai_nanny_structured_clarification.dart';
import 'breastfeeding_both_helper.dart';

/// Converte [AiNannyStructuredRecord] → [DetectedBabyRecord] + perguntas.
abstract final class DetectedRecordBuilder {
  static DetectedBabyRecord fromStructured(
    AiNannyStructuredRecord rec,
    S s, {
    double confidence = 0.92,
  }) {
    final understood = <String>[];
    final missing = <String>[];

    for (final line in AiNannyStructuredClarification.detailLines(rec, s)) {
      if (line.contains(s.aiRecordFieldMissing)) {
        missing.add(line);
      } else {
        understood.add(line);
      }
    }

    if (understood.isEmpty) {
      understood.add('• ${s.aiRecordFieldTime}: ${s.aiRecordFieldNow}');
    }

    final canSave = rec.missingFields.isEmpty;

    return DetectedBabyRecord(
      type: _publicType(rec.type, rec.fields),
      confidence: confidence,
      extractedFields: Map<String, dynamic>.from(rec.fields),
      missingFields: List<String>.from(rec.missingFields),
      suggestedTime: DateTime.now(),
      canSave: canSave,
      understoodLines: understood,
      missingLines: missing.isNotEmpty
          ? missing
          : rec.missingFields
              .map((f) => '• ${_fieldLabel(f, s)}: ${s.aiRecordFieldMissing}')
              .toList(),
    );
  }

  /// Primeira pergunta pendente de um único registro.
  static AiFollowUpQuestion? firstFollowUpForRecord(
    AiNannyStructuredRecord rec,
    int recordIndex,
    S s,
  ) {
    final qs = followUpsForRecord(rec, recordIndex, s);
    if (qs.isNotEmpty) return qs.first;
    final text = AiNannyStructuredClarification.followUpQuestion(rec, s);
    if (text == null || text.trim().isEmpty) return null;
    final field = rec.missingFields.isNotEmpty
        ? rec.missingFields.first
        : (rec.type == 'growth_weight' || rec.type == 'growth_height')
            ? 'value'
            : 'value';
    return AiFollowUpQuestion(
      recordIndex: recordIndex,
      recordType: _publicType(rec.type, rec.fields),
      field: field,
      question: text.trim(),
      inputType: AiFollowUpInputType.text,
    );
  }

  static List<AiFollowUpQuestion> followUpsForRecord(
    AiNannyStructuredRecord rec,
    int recordIndex,
    S s,
  ) {
    return followUpsForBundle(
      [
        AiNannyRecordDraft(
          structured: rec,
          status: AiNannyRecordDraftStatus.incomplete,
          displayLine: '',
          title: '',
        ),
      ],
      s,
    );
  }

  static List<AiFollowUpQuestion> followUpsForBundle(
    List<AiNannyRecordDraft> drafts,
    S s,
  ) {
    final out = <AiFollowUpQuestion>[];
    for (var i = 0; i < drafts.length; i++) {
      final rec = drafts[i].structured;
      if (rec.missingFields.isEmpty) continue;

      if (rec.type == 'feeding' || _publicType(rec.type, rec.fields) == 'breastfeeding') {
        final ft = '${rec.fields['feedingType'] ?? ''}';
        if (rec.missingFields.contains('feedingType')) {
          out.add(AiFollowUpQuestion(
            recordIndex: i,
            recordType: 'breastfeeding',
            field: 'feedingType',
            question: s.aiClarifyFeedingType,
            options: [s.aiRecordFeedingBreast, s.aiRecordFeedingBottle],
          ));
        }
        if (ft == 'breastfeeding' || rec.missingFields.contains('breastSide')) {
          if (rec.missingFields.contains('breastSide') &&
              rec.fields['fromActiveTimer'] != true) {
            out.add(AiFollowUpQuestion(
              recordIndex: i,
              recordType: 'breastfeeding',
              field: 'breastSide',
              question: s.aiFollowUpBreastSideQuestion,
              options: [s.aiRecordSideLeft, s.aiRecordSideRight, s.aiRecordSideBoth],
            ));
          }
        }
        if (rec.missingFields.contains('durationMinutes') &&
            rec.fields['fromActiveTimer'] != true) {
          final side = '${rec.fields['breastSide'] ?? ''}';
          out.add(AiFollowUpQuestion(
            recordIndex: i,
            recordType: 'breastfeeding',
            field: 'durationMinutes',
            question: BreastfeedingBothHelper.durationQuestionForSide(side, s),
            inputType: AiFollowUpInputType.number,
          ));
        }
        if (rec.missingFields.contains('amountMl')) {
          out.add(AiFollowUpQuestion(
            recordIndex: i,
            recordType: 'bottle',
            field: 'amountMl',
            question: s.aiClarifyBottleAmount,
            inputType: AiFollowUpInputType.number,
          ));
        }
        continue;
      }

      if (rec.type == 'diaper') {
        if (rec.missingFields.contains('pee') ||
            rec.missingFields.contains('poop')) {
          out.add(AiFollowUpQuestion(
            recordIndex: i,
            recordType: 'diaper',
            field: 'type',
            question: s.aiFollowUpDiaperTypeQuestion,
            options: [
              s.aiDiaperOptionPee,
              s.aiDiaperOptionPoo,
              s.aiDiaperOptionBoth,
            ],
          ));
        }
        continue;
      }

      if (rec.type == 'sleep') {
        if (rec.missingFields.contains('startedAt') ||
            rec.missingFields.contains('sleepStatus')) {
          out.add(AiFollowUpQuestion(
            recordIndex: i,
            recordType: 'sleep',
            field: 'sleepStatus',
            question: s.aiFollowUpSleepStatusQuestion,
            options: [
              s.aiSleepOptionFellAsleepNow,
              s.aiSleepOptionAlreadyWoke,
            ],
          ));
        }
        if (rec.missingFields.contains('durationMinutes') &&
            rec.fields['fromActiveTimer'] != true) {
          out.add(AiFollowUpQuestion(
            recordIndex: i,
            recordType: 'sleep',
            field: 'durationMinutes',
            question: s.aiFollowUpSleepDurationQuestion,
            inputType: AiFollowUpInputType.number,
          ));
        }
        continue;
      }

      if (rec.type == 'vaccine') {
        if (rec.missingFields.contains('vaccineName')) {
          out.add(AiFollowUpQuestion(
            recordIndex: i,
            recordType: 'vaccine',
            field: 'vaccineName',
            question: s.aiClarifyVaccineName,
            inputType: AiFollowUpInputType.text,
          ));
        }
        if (rec.missingFields.contains('date')) {
          out.add(AiFollowUpQuestion(
            recordIndex: i,
            recordType: 'vaccine',
            field: 'date',
            question: s.aiClarifyVaccineDate,
            inputType: AiFollowUpInputType.text,
          ));
        }
        continue;
      }

      if (rec.type == 'growth_weight' || rec.type == 'growth_height') {
        if (rec.missingFields.contains('value')) {
          out.add(AiFollowUpQuestion(
            recordIndex: i,
            recordType: rec.type,
            field: 'value',
            question: rec.type == 'growth_weight'
                ? s.aiGrowthNeedBaselineWeight
                : s.aiGrowthNeedBaselineHeight,
            inputType: AiFollowUpInputType.number,
          ));
        } else if (rec.fields['mode'] == 'delta' && rec.fields['value'] != null) {
          final grams = (rec.fields['value'] as num?)?.toInt() ?? 0;
          out.add(AiFollowUpQuestion(
            recordIndex: i,
            recordType: rec.type,
            field: 'value',
            question: rec.type == 'growth_weight'
                ? s.aiPendingGrowthNeedLastWeight(grams)
                : s.aiGrowthNeedBaselineHeight,
            inputType: AiFollowUpInputType.number,
          ));
        }
        continue;
      }

      if (rec.type == 'appointment') {
        if (rec.missingFields.contains('reasonOrSpecialty')) {
          out.add(AiFollowUpQuestion(
            recordIndex: i,
            recordType: 'appointment',
            field: 'reasonOrSpecialty',
            question: s.aiClarifyAppointmentReason,
            inputType: AiFollowUpInputType.text,
          ));
        }
        if (rec.missingFields.contains('date')) {
          out.add(AiFollowUpQuestion(
            recordIndex: i,
            recordType: 'appointment',
            field: 'date',
            question: s.aiClarifyAppointmentWhen,
            inputType: AiFollowUpInputType.text,
          ));
        }
        continue;
      }

      if (rec.type == 'health_symptom') {
        if (rec.missingFields.contains('temperatureCelsius')) {
          out.add(AiFollowUpQuestion(
            recordIndex: i,
            recordType: 'symptom',
            field: 'temperatureCelsius',
            question: s.aiClarifyFeverTemperature,
            inputType: AiFollowUpInputType.number,
          ));
        } else if (rec.missingFields.contains('symptoms')) {
          out.add(AiFollowUpQuestion(
            recordIndex: i,
            recordType: 'symptom',
            field: 'symptoms',
            question: s.aiClarifySymptomDetails,
            inputType: AiFollowUpInputType.text,
          ));
        }
      }
    }
    return out;
  }

  static String _publicType(String type, Map<String, dynamic> fields) {
    if (type == 'feeding') {
      final ft = '${fields['feedingType'] ?? ''}';
      if (ft == 'breastfeeding') return 'breastfeeding';
      if (ft == 'bottle' || ft == 'formula') return 'bottle';
      return 'feeding';
    }
    if (type == 'health_symptom') return 'symptom';
    if (type == 'growth_weight' || type == 'growth_height') return 'growth';
    return type;
  }

  static String _fieldLabel(String field, S s) => switch (field) {
        'breastSide' => s.aiRecordFieldSide,
        'durationMinutes' => s.aiRecordFieldDuration,
        'amountMl' => s.aiRecordFieldAmount,
        'pee' || 'poop' => s.aiRecordFieldType,
        'feedingType' => s.aiRecordFieldMethod,
        'startedAt' => s.aiRecordFieldTime,
        'sleepStatus' => s.aiRecordFieldAction,
        'action' => s.aiRecordFieldAction,
        _ => field,
      };

  /// Aplica resposta do utilizador ao rascunho.
  static AiNannyStructuredRecord applyAnswer({
    required AiNannyStructuredRecord rec,
    required String field,
    required String value,
    required String sourceText,
  }) {
    final fields = Map<String, dynamic>.from(rec.fields);
    final low = value.trim().toLowerCase();

    switch (field) {
      case 'breastSide':
        fields['feedingType'] = 'breastfeeding';
        fields['sideConfirmed'] = true;
        if (low.contains('esquer') || low == 'left' || low == 'e') {
          fields['breastSide'] = 'left';
        } else if (low.contains('direit') || low == 'right' || low == 'd') {
          fields['breastSide'] = 'right';
        } else if (low.contains('ambos') || low == 'both') {
          fields['breastSide'] = 'both';
        }
        break;
      case 'durationMinutes':
        var n = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
        n ??= AiNannyParseNormalize.parseDurationMinutes(value);
        n ??= AiNannyParseNormalize.parseDurationHoursAsMinutes(value);
        if (n != null) fields['durationMinutes'] = n;
        if (rec.type == 'feeding') {
          fields['feedingType'] ??= 'breastfeeding';
        }
        if (rec.type == 'sleep') {
          fields['action'] = 'end';
          fields['sleepStatus'] = 'woke';
        }
        break;
      case 'amountMl':
        final n = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
        if (n != null) fields['amountMl'] = n;
        fields['feedingType'] ??= 'bottle';
        break;
      case 'feedingType':
        if (low.contains('peito') || low.contains('breast')) {
          fields['feedingType'] = 'breastfeeding';
        } else {
          fields['feedingType'] = 'bottle';
        }
        break;
      case 'type':
        if (low.contains('xixi') || low.contains('pee')) {
          fields['pee'] = true;
          fields['poop'] = false;
        } else if (low.contains('coc') || low.contains('poop') || low.contains('poo')) {
          fields['pee'] = false;
          fields['poop'] = true;
        } else if (low.contains('ambos') || low.contains('both')) {
          fields['pee'] = true;
          fields['poop'] = true;
        }
        fields['time'] ??= 'now';
        break;
      case 'startedAt':
        fields['time'] = value.trim().isEmpty ? 'now' : value.trim();
        fields['action'] ??= 'start';
        break;
      case 'sleepStatus':
        if (low.contains('acord') ||
            low.contains('woke') ||
            low.contains('já') && low.contains('dorm')) {
          fields['action'] = 'end';
          fields['sleepStatus'] = 'woke';
        } else {
          fields['action'] = 'start';
          fields['sleepStatus'] = 'now';
          fields['time'] = 'now';
        }
        break;
      default:
        fields[field] = value;
    }

    var enforced = AiNannyStructuredClarification.enforce(
      AiNannyStructuredRecord(
        type: rec.type,
        fields: fields,
        missingFields: const [],
      ),
      '$sourceText $value',
    );

    if (field == 'breastSide' &&
        enforced.fields['breastSide'] == 'both' &&
        enforced.type == 'feeding') {
      enforced = AiNannyStructuredRecord(
        type: enforced.type,
        fields: Map<String, dynamic>.from(enforced.fields),
        missingFields: const ['durationMinutes'],
      );
    }

    return enforced;
  }
}
