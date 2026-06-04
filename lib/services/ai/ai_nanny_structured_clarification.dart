import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../models/ai/ai_nanny_system_context.dart';
import '../../models/ai/detected_baby_record.dart';
import '../../utils/ai_nanny_parse_normalize.dart';
import 'ai_nanny_intent_lexicon.dart';
import 'pending_records_explanation.dart';

/// Perguntas objetivas e cartões de confirmação — sem inventar dados obrigatórios.
abstract final class AiNannyStructuredClarification {
  /// Recalcula [missingFields] e remove valores não ditos na frase (anti-alucinação).
  static AiNannyStructuredRecord enforce(
    AiNannyStructuredRecord r,
    String sourceText, {
    AiNannySystemContext? systemContext,
  }) {
    final fields = Map<String, dynamic>.from(r.fields);
    final missing = <String>{...r.missingFields};
    final text = sourceText.trim();
    final low = text.toLowerCase();
    var resolvedType = AiNannyParseNormalize.canonicalRecordType(r.type, fields);

    if (!fields.containsKey('time') || '${fields['time'] ?? ''}'.isEmpty) {
      fields['time'] = 'now';
    }

    if (resolvedType == 'growth' ||
        resolvedType == 'crescimento' ||
        resolvedType == 'measurement') {
      final h = AiNannyParseNormalize.parseHeightDeltaCm(text);
      if (h != null) {
        resolvedType = 'growth_height';
        fields['measurementType'] = 'height';
        fields['value'] = h;
        fields['unit'] = 'cm';
        fields['mode'] = fields['mode'] ?? 'delta';
        missing.remove('value');
      } else {
        final g = AiNannyParseNormalize.parseWeightDeltaGrams(text);
        if (g != null) {
          resolvedType = 'growth_weight';
          fields['measurementType'] = 'weight';
          fields['value'] = g;
          fields['unit'] = 'g';
          fields['mode'] = fields['mode'] ?? 'delta';
          missing.remove('value');
        }
      }
    }

    if (resolvedType == 'wake' || resolvedType == 'woke' || resolvedType == 'awake') {
      resolvedType = 'sleep';
      fields['action'] = 'end';
      fields['sleepStatus'] = 'woke';
    }

    if (resolvedType == 'record' ||
        resolvedType == 'registro' ||
        resolvedType == 'entry') {
      resolvedType = 'record';
    }

    if (!AiNannyParseNormalize.knownRecordTypes.contains(resolvedType) ||
        resolvedType == 'record') {
      final h = AiNannyParseNormalize.parseHeightDeltaCm(text);
      if (h != null) {
        resolvedType = 'growth_height';
        fields['measurementType'] = 'height';
        fields['value'] = h;
        fields['unit'] = 'cm';
        fields['mode'] = fields['mode'] ?? 'delta';
        missing.remove('value');
      } else {
        final g = AiNannyParseNormalize.parseWeightDeltaGrams(text);
        if (g != null) {
          resolvedType = 'growth_weight';
          fields['measurementType'] = 'weight';
          fields['value'] = g;
          fields['unit'] = 'g';
          fields['mode'] = fields['mode'] ?? 'delta';
          missing.remove('value');
        } else if (AiNannyIntentLexicon.textImpliesWake(low)) {
          resolvedType = 'sleep';
          fields['action'] = 'end';
          fields['sleepStatus'] = 'woke';
        }
      }
    }

    switch (resolvedType) {
      case 'diaper':
        final pee = fields['pee'] == true;
        final poop = fields['poop'] == true;
        if (!pee && !poop) {
          missing.add('pee');
          missing.add('poop');
        }
        break;

      case 'feeding':
        final breastTimer = systemContext?.activeBreastfeeding;
        final feedingCue = AiNannyIntentLexicon.hasFeedingCue(low);
        final usedBreastTimer = systemContext != null &&
            systemContext.hasActiveBreastfeedingForBaby &&
            breastTimer != null &&
            feedingCue;
        if (usedBreastTimer) {
          fields['feedingType'] = 'breastfeeding';
          fields['breastSide'] = breastTimer.side == 'E'
              ? 'left'
              : breastTimer.side == 'D'
                  ? 'right'
                  : breastTimer.side.toLowerCase();
          fields['durationMinutes'] = breastTimer.durationMinutes;
          fields['fromActiveTimer'] = true;
          missing.remove('feedingType');
          missing.remove('breastSide');
          missing.remove('durationMinutes');
        }

        var ft = '${fields['feedingType'] ?? ''}'.toLowerCase();
        if (ft == 'breast' || ft == 'peito') ft = 'breastfeeding';
        if (!usedBreastTimer) {
          if (ft.isEmpty || ft == 'unknown') {
            if (low.contains('mamou') ||
                low.contains('mamada') ||
                low.contains('amament') ||
                low.contains('peito')) {
              fields['feedingType'] = 'breastfeeding';
              ft = 'breastfeeding';
              missing.remove('feedingType');
            } else {
              missing.add('feedingType');
            }
          } else {
            fields['feedingType'] = ft;
          }
          if (ft == 'breastfeeding') {
            final existingSide = '${fields['breastSide'] ?? ''}'.toLowerCase();
            if (existingSide == 'both') {
              fields['breastSide'] = 'both';
              missing.remove('breastSide');
              fields.remove('durationMinutes');
              missing.add('durationMinutes');
            } else if ((existingSide == 'left' || existingSide == 'right') &&
                (fields['fromActiveTimer'] == true ||
                    fields['sideConfirmed'] == true)) {
              fields['breastSide'] = existingSide;
              missing.remove('breastSide');
            } else {
              final sideInText =
                  AiNannyParseNormalize.parseBreastSideCanonical(text);
              if (sideInText == null) {
                fields.remove('breastSide');
                missing.add('breastSide');
              } else {
                fields['breastSide'] = sideInText;
                missing.remove('breastSide');
              }
            }
            final hasDuration = fields['durationMinutes'] != null;
            if (!hasDuration) {
              var minsInText = AiNannyParseNormalize.parseDurationMinutes(text);
              minsInText ??=
                  AiNannyParseNormalize.parseDurationHoursAsMinutes(text);
              if (minsInText == null) {
                fields.remove('durationMinutes');
                missing.add('durationMinutes');
              } else {
                fields['durationMinutes'] = minsInText;
                missing.remove('durationMinutes');
              }
            } else {
              missing.remove('durationMinutes');
            }
          }
        }
        if (ft == 'bottle' || ft == 'formula' || ft == 'expressed_milk') {
          final ml = AiNannyParseNormalize.parseAmountMl(text);
          if (ml == null) {
            fields.remove('amountMl');
            missing.add('amountMl');
          } else {
            fields['amountMl'] = ml;
            missing.remove('amountMl');
          }
        }
        break;

      case 'health_symptom':
        final syms = fields['symptoms'];
        var hasSym =
            syms is List && syms.isNotEmpty || fields['temperatureCelsius'] != null;
        if (AiNannyIntentLexicon.hasTemperatureCue(text.toLowerCase())) {
          if (syms is! List || syms.isEmpty) {
            fields['symptoms'] = ['fever'];
          }
          fields['feverReported'] = true;
          hasSym = true;
        }
        final temp = fields['temperatureCelsius'] ??
            AiNannyParseNormalize.parseTemperatureCelsius(text);
        if (temp != null) {
          fields['temperatureCelsius'] = temp;
          missing.remove('temperatureCelsius');
        } else if (fields['feverReported'] == true ||
            (syms is List &&
                syms.any((s) => '$s'.toLowerCase().contains('fever')))) {
          missing.add('temperatureCelsius');
        }
        if (!hasSym) missing.add('symptoms');
        else {
          missing.remove('symptoms');
        }
        break;

      case 'vaccine':
        final inferredName = AiNannyParseNormalize.inferVaccineName(text);
        if ('${fields['vaccineName'] ?? ''}'.trim().isEmpty) {
          if (inferredName != null) {
            fields['vaccineName'] = inferredName;
            missing.remove('vaccineName');
          } else {
            missing.add('vaccineName');
          }
        } else {
          missing.remove('vaccineName');
        }
        fields['status'] = AiNannyParseNormalize.inferVaccineStatus(text);
        final nextDaysFromText =
            AiNannyParseNormalize.parseVaccineNextDueInDays(text);
        final nextDaysCloud =
            AiNannyParseNormalize.coercePositiveInt(fields['nextDueInDays']);
        final nextDays = nextDaysFromText ?? nextDaysCloud;
        if (nextDays != null) {
          fields['nextDueInDays'] = nextDays;
          fields['nextDueDate'] =
              AiNannyParseNormalize.parseVaccineNextDueDateIso(text) ??
                  AiNannyParseNormalize.nextDueIsoFromDays(nextDays);
        } else {
          final cloudDate = '${fields['nextDueDate'] ?? ''}'.trim();
          if (cloudDate.isNotEmpty) {
            fields['nextDueDate'] = cloudDate;
          }
        }
        if (fields['status'] == 'scheduled') {
          fields.remove('date');
        } else {
          final vDate = AiNannyParseNormalize.parseAppointmentDate(text) ??
              '${fields['date'] ?? ''}'.trim();
          if (vDate.isNotEmpty) {
            fields['date'] = vDate;
          }
        }
        if (fields['status'] == 'scheduled' &&
            '${fields['date'] ?? ''}'.isEmpty &&
            '${fields['nextDueDate'] ?? ''}'.isEmpty &&
            fields['nextDueInDays'] == null) {
          missing.add('date');
        } else {
          missing.remove('date');
        }
        break;

      case 'appointment':
        final inferredReason =
            AiNannyParseNormalize.inferAppointmentReason(text);
        if ('${fields['reasonOrSpecialty'] ?? ''}'.trim().isEmpty) {
          if (inferredReason != null) {
            fields['reasonOrSpecialty'] = inferredReason;
            missing.remove('reasonOrSpecialty');
          } else {
            missing.add('reasonOrSpecialty');
          }
        } else {
          missing.remove('reasonOrSpecialty');
        }
        final parsedDate =
            AiNannyParseNormalize.parseAppointmentDate(text) ??
                '${fields['date'] ?? ''}'.trim();
        if (parsedDate.isNotEmpty) {
          fields['date'] = parsedDate;
          missing.remove('date');
        } else if (!_hasDateInText(text)) {
          missing.add('date');
        }
        final parsedTime = AiNannyParseNormalize.parseTime24h(text);
        if (parsedTime != null) {
          fields['time'] = parsedTime;
        } else {
          fields.remove('time');
        }
        missing.remove('time');
        break;

      case 'growth_weight':
        var wVal = fields['value'];
        var wMode = '${fields['mode'] ?? 'total'}';
        if (wVal == null) {
          final kg = AiNannyParseNormalize.parseWeightKgTotal(text);
          final deltaG = AiNannyParseNormalize.parseWeightDeltaGrams(text);
          if (kg != null) {
            fields['value'] = kg;
            fields['mode'] = 'total';
            fields['unit'] = 'kg';
            wVal = kg;
            wMode = 'total';
          } else if (deltaG != null) {
            fields['value'] = deltaG;
            fields['mode'] = 'delta';
            fields['unit'] = 'g';
            wVal = deltaG;
            wMode = 'delta';
          } else {
            missing.add('value');
          }
        }
        if (wVal != null) {
          missing.remove('value');
          AiNannyParseNormalize.normalizeGrowthWeightFields(fields, text);
          wMode = '${fields['mode'] ?? 'total'}';
          fields['mode'] = wMode;
        }
        missing.remove('time');
        break;

      case 'growth_height':
        var hVal = fields['value'];
        var hMode = '${fields['mode'] ?? 'total'}';
        if (hVal == null) {
          final cm = AiNannyParseNormalize.parseHeightCmTotal(text);
          final deltaCm = AiNannyParseNormalize.parseHeightDeltaCm(text);
          if (cm != null && cm >= 30) {
            fields['value'] = cm;
            fields['mode'] = 'total';
            fields['unit'] = 'cm';
            hVal = cm;
            hMode = 'total';
          } else if (deltaCm != null && deltaCm > 0) {
            fields['value'] = deltaCm;
            fields['mode'] = 'delta';
            fields['unit'] = 'cm';
            hVal = deltaCm;
            hMode = 'delta';
          } else {
            missing.add('value');
          }
        }
        if (hVal != null) {
          missing.remove('value');
          fields['mode'] = hMode;
        }
        missing.remove('time');
        break;

      case 'sleep':
        var action = '${fields['action'] ?? 'start'}';
        var sleepStatus = '${fields['sleepStatus'] ?? ''}';
        if (systemContext?.hasActiveSleepForBaby == true &&
            AiNannyIntentLexicon.textImpliesWake(low)) {
          action = 'end';
          sleepStatus = 'woke';
          fields['action'] = action;
          fields['sleepStatus'] = sleepStatus;
        }
        final waking = sleepStatus == 'woke' || action == 'end';
        if (waking) {
          fields['sleepStatus'] = 'woke';
          fields['action'] = 'end';

          final timer = systemContext?.activeSleep;
          if (systemContext != null &&
              systemContext.hasActiveSleepForBaby &&
              timer != null) {
            fields['durationMinutes'] = timer.durationMinutes;
            fields['durationSec'] = timer.durationSec;
            fields['startedAt'] = timer.startedAt.toIso8601String();
            fields['fromActiveTimer'] = true;
            missing.remove('durationMinutes');
            missing.remove('startedAt');
            missing.remove('sleepStatus');
          } else {
            var mins = AiNannyParseNormalize.parseSleepDurationMinutes(text);
            if (mins == null) {
              missing.add('durationMinutes');
            } else {
              fields['durationMinutes'] = mins;
              missing.remove('durationMinutes');
            }
          }
        } else {
          var mins = (fields['durationMinutes'] as num?)?.toInt();
          mins ??= AiNannyParseNormalize.parseSleepDurationMinutes(text);
          final endTime = AiNannyParseNormalize.parseTime24h(text);

          if (mins != null &&
              mins > 0 &&
              (AiNannyParseNormalize.textImpliesCompletedSleep(text) ||
                  action == 'complete')) {
            fields['action'] = 'complete';
            fields['durationMinutes'] = mins;
            fields['sleepStatus'] = 'slept';
            final started = AiNannyParseNormalize.computeSleepStartedAt(
              durationMinutes: mins,
              endTime24h: endTime,
            );
            if (started != null) {
              fields['startedAt'] = started.toIso8601String();
            }
            if (endTime != null) fields['time'] = endTime;
            missing.remove('durationMinutes');
            missing.remove('startedAt');
            missing.remove('sleepStatus');
          } else if (AiNannyParseNormalize.textImpliesSleepStartNow(text) ||
              action == 'start') {
            fields['action'] = 'start';
            fields['sleepStatus'] = 'now';
            fields['startedAt'] = DateTime.now().toIso8601String();
            fields['time'] = 'now';
            missing.remove('startedAt');
            missing.remove('sleepStatus');
            missing.remove('durationMinutes');
          } else if (endTime != null || low.contains('agora')) {
            fields['time'] = endTime ?? 'now';
            missing.remove('startedAt');
            missing.remove('sleepStatus');
          } else {
            missing.add('sleepStatus');
            missing.add('startedAt');
          }
        }
        break;

      default:
        break;
    }

    final cleanedMissing =
        AiNannyParseNormalize.sanitizeMissingForType(resolvedType, missing);
    missing
      ..clear()
      ..addAll(cleanedMissing);

    return AiNannyStructuredRecord(
      type: resolvedType,
      missingFields: missing.toList()..sort(),
      fields: fields,
    );
  }

  static bool _hasDateInText(String text) {
    final low = text.toLowerCase();
    return AiNannyParseNormalize.parseAppointmentDate(text) != null ||
        low.contains('hoje') ||
        low.contains('today') ||
        low.contains('amanh') ||
        low.contains('tomorrow') ||
        RegExp(r'\d{1,2}[/-]\d{1,2}').hasMatch(low);
  }

  static String buildClarificationForBundle(AiNannyRecordsBundle bundle, S s) {
    final blocks = <String>[];
    for (final d in bundle.drafts) {
      if (d.status != AiNannyRecordDraftStatus.incomplete) continue;
      final q = d.followUpQuestion?.trim();
      if (q != null && q.isNotEmpty) {
        blocks.add(q);
      }
    }
    if (blocks.isEmpty) return '';
    if (blocks.length == 1) return blocks.single;
    return blocks.asMap().entries.map((e) => '${e.key + 1}) ${e.value}').join('\n\n');
  }

  /// Mensagem de chat com a pergunta explícita — nunca só “falta um detalhe”.
  static String explicitChatReply({
    required AiNannyRecordsBundle? bundle,
    required S strings,
    String? clarificationPrompt,
    double? lastWeightKg,
  }) {
    final clarify = clarificationPrompt?.trim() ?? '';
    if (clarify.isNotEmpty) return clarify;

    if (bundle != null) {
      final explained = PendingRecordsExplanation.buildPendingRecordsExplanation(
        bundle: bundle,
        strings: strings,
        lastWeightKg: lastWeightKg,
      );
      if (explained != null && explained.isNotEmpty) return explained;
      if (PendingRecordsExplanation.hasRealPending(bundle: bundle)) {
        return buildActionFirstReply(bundle, strings);
      }
    }
    return '';
  }

  /// Resposta no chat sem chamar GPT motivacional — acção primeiro.
  static String buildActionFirstReply(AiNannyRecordsBundle bundle, S s) {
    final explained = PendingRecordsExplanation.buildPendingRecordsExplanation(
      bundle: bundle,
      strings: s,
    );
    if (explained != null && explained.isNotEmpty) return explained;

    final n = bundle.drafts.length;
    if (bundle.allRequiredFilled) {
      final needsConfirm = bundle.drafts.any(
        (d) => d.status == AiNannyRecordDraftStatus.needsConfirm,
      );
      if (!needsConfirm) return s.aiActionFirstAllComplete(n);
    }

    final buf = StringBuffer()
      ..writeln(s.aiActionFirstFoundIntro)
      ..writeln();

    if (n == 1) {
      buf.writeln(s.aiActionFirstSummarySingle);
    } else {
      buf.writeln(s.aiActionFirstSummaryHeader(n));
    }

    for (final d in bundle.drafts) {
      final label = recordTitle(
        d.structured,
        s,
        sourceText: bundle.userMessage,
      );
      final mark = d.structured.missingFields.isEmpty ? '✅' : '⚠️';
      buf.writeln('$mark $label');
    }

    final qs = bundle.followUpQuestions;
    if (qs.isNotEmpty) {
      buf
        ..writeln()
        ..writeln(s.aiActionFirstFirstQuestionLead)
        ..write(formatFollowUpMessage(question: qs.first));
    } else if (bundle.incompleteCount > 0) {
      final fallback = PendingRecordsExplanation.buildPendingRecordsExplanation(
        bundle: bundle,
        strings: s,
      );
      if (fallback != null) {
        buf
          ..writeln()
          ..writeln(fallback);
      }
    }
    return buf.toString().trim();
  }

  /// Após uma resposta válida — confirma e faz a próxima pergunta explícita.
  static String formatAfterAnswer({
    required S strings,
    required AiFollowUpQuestion question,
  }) {
    return formatFollowUpMessage(
      intro: '${strings.aiPendingAnswerAck}\n\n${strings.aiActionFirstNextQuestionLead}',
      question: question,
    );
  }

  /// Pergunta com opções em bullets (chat + voz).
  static String formatFollowUpMessage({
    String? intro,
    required AiFollowUpQuestion question,
  }) {
    final buf = StringBuffer();
    if (intro != null && intro.trim().isNotEmpty) {
      buf.writeln(intro.trim());
      buf.writeln();
    }
    buf.writeln(question.question.trim());
    if (question.options.isNotEmpty) {
      for (final opt in question.options) {
        buf.writeln('• $opt');
      }
    }
    return buf.toString().trim();
  }

  static String? followUpQuestion(AiNannyStructuredRecord r, S s) {
    if (r.missingFields.isEmpty) return null;

    switch (r.type) {
      case 'feeding':
        if (r.missingFields.contains('feedingType')) {
          return '${s.aiClarifyFeedingPrefix}\n${s.aiClarifyFeedingTypeOptions}';
        }
        if (r.missingFields.contains('breastSide')) {
          return '${s.aiClarifyFeedingPrefix}\n${s.aiClarifyBreastSideOptions}';
        }
        if (r.missingFields.contains('durationMinutes')) {
          return '${s.aiClarifyFeedingPrefix} ${s.aiClarifyFeedingDuration}';
        }
        if (r.missingFields.contains('amountMl')) {
          return '${s.aiClarifyFeedingPrefix} ${s.aiClarifyBottleAmount}';
        }
        break;
      case 'diaper':
        if (r.missingFields.contains('pee') ||
            r.missingFields.contains('poop')) {
          return '${s.aiClarifyDiaperPrefix}\n${s.aiClarifyDiaperKindOptions}';
        }
        break;
      case 'sleep':
        if (r.missingFields.contains('startedAt')) {
          return s.aiClarifySleepStart;
        }
        break;
      case 'vaccine':
        if (r.missingFields.contains('vaccineName')) {
          return s.aiClarifyVaccineName;
        }
        if (r.missingFields.contains('date')) {
          return s.aiClarifyVaccineDate;
        }
        break;
      case 'growth_weight':
        if (r.fields['mode'] == 'delta' && r.fields['value'] != null) {
          final grams = (r.fields['value'] as num?)?.toInt() ?? 0;
          return s.aiPendingGrowthNeedLastWeight(grams);
        }
        if (r.missingFields.contains('value')) {
          return s.aiGrowthNeedBaselineWeight;
        }
        break;
      case 'growth_height':
        if (r.fields['mode'] == 'delta' && r.fields['value'] != null) {
          return s.aiGrowthNeedBaselineHeight;
        }
        break;
      case 'appointment':
        if (r.missingFields.contains('reasonOrSpecialty')) {
          return s.aiClarifyAppointmentReason;
        }
        if (r.missingFields.contains('date') ||
            r.missingFields.contains('time')) {
          return s.aiClarifyAppointmentWhen;
        }
        break;
      case 'health_symptom':
        if (r.missingFields.contains('temperatureCelsius')) {
          return s.aiClarifyFeverTemperature;
        }
        if (r.missingFields.contains('symptoms')) {
          return s.aiClarifySymptomDetails;
        }
        break;
      default:
        break;
    }
    return null;
  }

  static String recordTitle(
    AiNannyStructuredRecord r,
    S s, {
    String? sourceText,
  }) {
    final type = AiNannyParseNormalize.canonicalRecordType(r.type, r.fields);
    if (type == 'feeding') {
      var ft = '${r.fields['feedingType'] ?? ''}'.toLowerCase();
      if (ft.isEmpty && sourceText != null) {
        final low = sourceText.toLowerCase();
        if (low.contains('mamou') ||
            low.contains('mamada') ||
            low.contains('peito')) {
          ft = 'breastfeeding';
        }
      }
      if (ft == 'breastfeeding') return s.aiRecordLabelBreastfeeding;
      if (ft == 'bottle' || ft == 'formula' || ft == 'expressed_milk') {
        return s.aiRecordLabelBottle;
      }
      return s.aiRecordLabelFeeding;
    }
    return switch (type) {
      'diaper' => s.aiRecordLabelDiaper,
      'sleep' => s.aiRecordLabelSleep,
      'health_symptom' => s.aiRecordLabelSymptom,
      'growth_weight' => s.growthTabWeight,
      'growth_height' => s.growthTabHeight,
      'vaccine' => s.aiRecordLabelVaccine,
      'appointment' => s.aiRecordLabelAppointment,
      'memory' => s.aiRecordLabelMemory,
      _ => s.aiRecordLineGeneric,
    };
  }

  static List<String> detailLines(AiNannyStructuredRecord r, S s) {
    final lines = <String>[];
    final type = AiNannyParseNormalize.canonicalRecordType(r.type, r.fields);
    final missing = r.missingFields.toSet();

    String field(String label, String? value, {bool isMissing = false}) {
      if (isMissing || value == null || value.isEmpty) {
        return '• $label: ${s.aiRecordFieldMissing}';
      }
      return '• $label: $value';
    }

    final timeLabel = _formatTime(r.fields['time'], s);

    switch (type) {
      case 'feeding':
        final ft = '${r.fields['feedingType'] ?? ''}';
        lines.add(
          field(
            s.aiRecordFieldMethod,
            missing.contains('feedingType') ? null : _feedingTypeLabel(ft, s),
            isMissing: missing.contains('feedingType'),
          ),
        );
        if (ft == 'breastfeeding' || ft.isEmpty) {
          lines.add(
            field(
              s.aiRecordFieldSide,
              missing.contains('breastSide')
                  ? null
                  : _sideLabel('${r.fields['breastSide'] ?? ''}', s),
              isMissing: missing.contains('breastSide'),
            ),
          );
          final mins = r.fields['durationMinutes'];
          lines.add(
            field(
              s.aiRecordFieldDuration,
              missing.contains('durationMinutes')
                  ? null
                  : (mins != null ? '$mins min' : null),
              isMissing: missing.contains('durationMinutes'),
            ),
          );
        }
        final ml = r.fields['amountMl'];
        if (ft == 'bottle' ||
            ft == 'formula' ||
            missing.contains('amountMl')) {
          lines.add(
            field(
              s.aiRecordFieldAmount,
              ml != null ? '$ml ml' : null,
              isMissing: missing.contains('amountMl'),
            ),
          );
        }
        lines.add(field(s.aiRecordFieldTime, timeLabel));
        break;

      case 'diaper':
        final pee = r.fields['pee'] == true;
        final poop = r.fields['poop'] == true;
        String? typeLabel;
        if (pee && poop) {
          typeLabel = s.aiRecordLineDiaperBoth;
        } else if (pee) {
          typeLabel = s.aiRecordLineDiaperPee;
        } else if (poop) {
          typeLabel = s.aiRecordLineDiaperPoo;
        }
        lines.add(
          field(
            s.aiRecordFieldType,
            typeLabel,
            isMissing:
                missing.contains('pee') || missing.contains('poop'),
          ),
        );
        lines.add(field(s.aiRecordFieldTime, timeLabel));
        break;

      case 'sleep':
        final action = '${r.fields['action'] ?? 'start'}';
        final waking =
            action == 'end' || '${r.fields['sleepStatus'] ?? ''}' == 'woke';
        lines.add(field(s.aiRecordFieldAction, _sleepActionLabel(action, s)));
        final mins = r.fields['durationMinutes'];
        if (mins != null) {
          lines.add(field(s.aiRecordFieldDuration, '$mins min'));
        } else if (waking) {
          lines.add('• ${s.aiSleepOptionAlreadyWoke}');
        }
        lines.add(
          field(
            s.aiRecordFieldTime,
            missing.contains('startedAt') ? null : timeLabel,
            isMissing: missing.contains('startedAt'),
          ),
        );
        break;

      case 'health_symptom':
        final temp = r.fields['temperatureCelsius'];
        if (temp != null) {
          lines.add(field(s.aiRecordFieldTemperature, '${temp}°C'));
        }
        final syms = r.fields['symptoms'];
        if (syms is List && syms.isNotEmpty) {
          lines.add(field(s.aiRecordFieldSymptoms, syms.join(', ')));
        } else if (missing.contains('symptoms')) {
          lines.add(field(s.aiRecordFieldSymptoms, null, isMissing: true));
        }
        lines.add(field(s.aiRecordFieldTime, timeLabel));
        break;

      case 'growth_weight':
      case 'growth_height':
        final mode = '${r.fields['mode'] ?? 'total'}';
        final v = r.fields['value'];
        final unit =
            r.fields['unit'] ?? (type == 'growth_weight' ? 'kg' : 'cm');
        final valueMissing = missing.contains('value') || v == null;
        lines.add(
          field(
            s.aiRecordFieldValue,
            valueMissing
                ? null
                : (mode == 'delta' ? '+$v $unit' : '$v $unit'),
            isMissing: valueMissing,
          ),
        );
        lines.add(field(s.aiRecordFieldTime, timeLabel));
        break;

      case 'vaccine':
        lines.add(
          field(
            s.aiRecordFieldName,
            '${r.fields['vaccineName'] ?? ''}'.trim().isEmpty
                ? null
                : '${r.fields['vaccineName']}',
            isMissing: missing.contains('vaccineName'),
          ),
        );
        lines.add(field(s.aiRecordFieldStatus, '${r.fields['status'] ?? ''}'));
        lines.add(
          field(
            s.aiRecordFieldDate,
            '${r.fields['date'] ?? ''}'.isEmpty ? null : '${r.fields['date']}',
            isMissing: missing.contains('date'),
          ),
        );
        final nextDue = '${r.fields['nextDueDate'] ?? ''}'.trim();
        final nextDays = (r.fields['nextDueInDays'] as num?)?.toInt();
        if (nextDue.isNotEmpty) {
          lines.add(field(s.vaccNext, nextDue));
        } else if (nextDays != null && nextDays > 0) {
          lines.add(field(s.vaccNext, '$nextDays dias'));
        }
        break;

      case 'appointment':
        lines.add(
          field(
            s.aiRecordFieldReason,
            '${r.fields['reasonOrSpecialty'] ?? ''}'.trim().isEmpty
                ? null
                : '${r.fields['reasonOrSpecialty']}',
            isMissing: missing.contains('reasonOrSpecialty'),
          ),
        );
        lines.add(
          field(
            s.aiRecordFieldDate,
            '${r.fields['date'] ?? ''}'.isEmpty ? null : '${r.fields['date']}',
            isMissing: missing.contains('date'),
          ),
        );
        final apptTime = '${r.fields['time'] ?? ''}'.trim();
        if (apptTime.isNotEmpty && apptTime != 'now') {
          lines.add(field(s.aiRecordFieldTime, apptTime));
        }
        break;

      default:
        if (type == 'growth_height' || type == 'growth_weight') {
          return detailLines(
            AiNannyStructuredRecord(
              type: type,
              missingFields: r.missingFields,
              fields: r.fields,
            ),
            s,
          );
        }
        break;
    }

    return lines.where((l) => l.trim().isNotEmpty).toList();
  }

  static String _formatTime(Object? time, S s) {
    final t = '$time'.trim();
    if (t.isEmpty || t == 'now') return s.aiRecordFieldNow;
    return t;
  }

  static String _feedingTypeLabel(String ft, S s) {
    return switch (ft) {
      'breastfeeding' => s.aiRecordFeedingBreast,
      'bottle' => s.aiRecordFeedingBottle,
      'formula' => s.aiRecordFeedingFormula,
      'expressed_milk' => s.aiRecordFeedingExpressed,
      _ => ft,
    };
  }

  static String _sideLabel(String side, S s) {
    return switch (side) {
      'left' => s.aiRecordSideLeft,
      'right' => s.aiRecordSideRight,
      'both' => s.aiRecordSideBoth,
      _ => side,
    };
  }

  static String _sleepActionLabel(String action, S s) {
    return switch (action) {
      'end' => s.aiRecordLineSleepEnd,
      'complete' => s.aiRecordLineSleep,
      _ => s.aiRecordLineSleepStart,
    };
  }
}
