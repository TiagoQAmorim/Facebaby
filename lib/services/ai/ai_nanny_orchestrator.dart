import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../models/ai/ai_nanny_system_context.dart';
import '../../models/ai/detected_baby_record.dart';
import 'ai_nanny_intent_lexicon.dart';
import 'ai_nanny_structured_clarification.dart';
import 'detected_record_builder.dart';
import 'pending_records_explanation.dart';

/// Enriquece parse com estado real do app e monta respostas inteligentes.
abstract final class AiNannyOrchestrator {
  static AiNannyParseResult enrichParse({
    required AiNannyParseResult parse,
    required AiNannySystemContext context,
    required String sourceText,
  }) {
    if (!parse.hasRecords) return parse;
    final records = parse.records
        .map((r) => enrichRecord(r, context: context, sourceText: sourceText))
        .toList();
    return AiNannyParseResult(
      classification: parse.classification,
      records: records,
      needsConfirmation: parse.needsConfirmation,
    );
  }

  static AiNannyStructuredRecord enrichRecord(
    AiNannyStructuredRecord rec, {
    required AiNannySystemContext context,
    required String sourceText,
  }) {
    return AiNannyStructuredClarification.enforce(
      rec,
      sourceText,
      systemContext: context,
    );
  }

  /// Remove perguntas sobre dados que o app já tem via cronômetro.
  static List<AiFollowUpQuestion> filterFollowUps(
    List<AiFollowUpQuestion> questions,
    List<AiNannyRecordDraft> drafts,
  ) {
    return questions.where((q) {
      if (q.recordIndex < 0 || q.recordIndex >= drafts.length) return true;
      final rec = drafts[q.recordIndex].structured;
      if (rec.fields['fromActiveTimer'] != true) return true;
      const timerFilled = {
        'durationMinutes',
        'breastSide',
        'startedAt',
        'sleepStatus',
      };
      return !timerFilled.contains(q.field);
    }).toList();
  }

  /// Resposta principal: confirmação inteligente ou fluxo de perguntas explícitas.
  static String buildSmartReply(
    AiNannyRecordsBundle bundle,
    AiNannySystemContext context,
    S strings, {
    bool compactForChat = false,
  }) {
    if (compactForChat) {
      final q = PendingRecordsExplanation.buildPendingRecordsExplanation(
        bundle: bundle,
        strings: strings,
        compactForChat: true,
      );
      if (q != null && q.isNotEmpty) return q;
    }
    final ready = buildReadyToConfirmReply(bundle, context, strings);
    if (ready != null) return ready;
    return AiNannyStructuredClarification.buildActionFirstReply(bundle, strings);
  }

  /// Resposta curta quando tudo está pronto (timers preenchidos).
  static String? buildReadyToConfirmReply(
    AiNannyRecordsBundle bundle,
    AiNannySystemContext context,
    S strings,
  ) {
    if (!bundle.allRequiredFilled) return null;

    final sleepEnd = bundle.drafts.where(
      (d) =>
          d.structured.type == 'sleep' &&
          '${d.structured.fields['action']}' == 'end',
    );
    final feedings = bundle.drafts.where((d) => d.structured.type == 'feeding');
    final diapers = bundle.drafts.where((d) => d.structured.type == 'diaper');

    if (sleepEnd.isNotEmpty && context.hasActiveSleepForBaby) {
      final sleep = context.activeSleep!;
      final dur = sleep.durationLabel;
      final diaperPart = _diaperSummary(diapers, strings);
      if (diaperPart.isNotEmpty) {
        return strings.aiOrchestratorFinishSleepAndDiaper(dur, diaperPart);
      }
      if (sleepEnd.first.structured.fields['fromActiveTimer'] == true) {
        return strings.aiOrchestratorFinishSleepWithStartedAt(
          sleep.startedAtClockLabel(),
          dur,
        );
      }
      return strings.aiOrchestratorFinishSleepOnly(dur);
    }

    if (feedings.isNotEmpty &&
        context.hasActiveBreastfeedingForBaby &&
        feedings.first.structured.fields['fromActiveTimer'] == true) {
      final bt = context.activeBreastfeeding!;
      return strings.aiOrchestratorFinishBreastfeeding(
        _breastSideLabel(bt, strings),
        bt.durationLabel,
      );
    }

    if (bundle.drafts.length == 1 && diapers.length == 1) {
      return null;
    }

    final growthConfirm = bundle.drafts.where(
      (d) =>
          d.status == AiNannyRecordDraftStatus.needsConfirm &&
          d.growthPreview != null,
    );
    if (growthConfirm.isNotEmpty) {
      final explained = PendingRecordsExplanation.buildPendingRecordsExplanation(
        bundle: bundle,
        strings: strings,
      );
      if (explained != null) return explained;
    }

    final hasOnlyComplete = bundle.drafts.every(
      (d) =>
          d.status == AiNannyRecordDraftStatus.complete ||
          d.status == AiNannyRecordDraftStatus.needsConfirm,
    );
    if (hasOnlyComplete && bundle.confirmCount == bundle.drafts.length) {
      final explained = PendingRecordsExplanation.buildPendingRecordsExplanation(
        bundle: bundle,
        strings: strings,
      );
      if (explained != null) return explained;
    }

    final hasGrowthDelta = bundle.drafts.any(
      (d) =>
          d.structured.type == 'growth_weight' &&
          (d.structured.fields['mode'] == 'delta' ||
              '${d.structured.fields['unit'] ?? ''}'.toLowerCase() == 'g'),
    );
    if (hasGrowthDelta) {
      final explained = PendingRecordsExplanation.buildPendingRecordsExplanation(
        bundle: bundle,
        strings: strings,
      );
      if (explained != null) return explained;
    }

    return strings.aiActionFirstAllComplete(bundle.drafts.length);
  }

  static String _breastSideLabel(ActiveBreastfeedingSessionInfo info, S strings) {
    final s = info.side.toUpperCase();
    if (s == 'E' || s == 'LEFT') return strings.aiRecordSideLeft;
    if (s == 'D' || s == 'RIGHT') return strings.aiRecordSideRight;
    return info.side;
  }

  static String _diaperSummary(
    Iterable<AiNannyRecordDraft> diapers,
    S strings,
  ) {
    if (diapers.isEmpty) return '';
    final rec = diapers.first.structured;
    final pee = rec.fields['pee'] == true;
    final poop = rec.fields['poop'] == true;
    if (pee && poop) return strings.aiOrchestratorDiaperBoth;
    if (pee) return strings.aiOrchestratorDiaperPee;
    if (poop) return strings.aiOrchestratorDiaperPoo;
    return strings.aiRecordLabelDiaper.toLowerCase();
  }

  /// Indica se o registro de sono deve finalizar timer ativo (acordou).
  static bool sleepRecordEndsActiveTimer(AiNannyStructuredRecord rec) =>
      rec.type == 'sleep' &&
      '${rec.fields['action']}' == 'end' &&
      rec.fields['fromActiveTimer'] == true;
}
