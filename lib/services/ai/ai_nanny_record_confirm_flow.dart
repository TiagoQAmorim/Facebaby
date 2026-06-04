import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../models/ai/voice_record_interpretation.dart';
import '../../utils/voice_record_clarification.dart';
import 'breastfeeding_both_helper.dart';
import 'ai_nanny_record_actions.dart';
import 'ai_nanny_structured_clarification.dart';
import 'ai_nanny_structured_mapper.dart';
import 'pending_records_explanation.dart';
import 'pending_routine_record_store.dart';

/// Resultado após o utilizador confirmar o card de registros.
class AiNannyConfirmSaveResult {
  const AiNannyConfirmSaveResult({
    this.savedCount = 0,
    this.pendingIncomplete = const [],
    this.errors = const [],
    this.confirmationLines = const [],
    this.remainingBundle,
    this.statusSummary,
  });

  final int savedCount;
  final List<AiNannyStructuredRecord> pendingIncomplete;
  final List<String> errors;
  final List<String> confirmationLines;
  /// Bundle só com rascunhos ainda não gravados (após save parcial).
  final AiNannyRecordsBundle? remainingBundle;
  /// Resumo ✅/⚠️ para chat após save parcial.
  final String? statusSummary;
}

/// Resultado ao gravar rascunhos já completos durante a sessão pendente.
class AiNannyDraftsPersistResult {
  const AiNannyDraftsPersistResult({
    this.remainingDrafts = const [],
    this.confirmationLines = const [],
    this.errors = const [],
    this.savedCount = 0,
  });

  final List<AiNannyRecordDraft> remainingDrafts;
  final List<String> confirmationLines;
  final List<String> errors;
  final int savedCount;

  bool get anySaved => savedCount > 0;
}

enum AiNannyConfirmMode {
  /// Só registros completos (e deltas confirmados).
  completeOnly,

  /// Completos + deltas de crescimento confirmados.
  allPossible,
}

AiNannyConfirmMode confirmModeForBundle(AiNannyRecordsBundle bundle) {
  final needsGrowth = bundle.drafts.any(
    (d) =>
        d.status == AiNannyRecordDraftStatus.needsConfirm &&
        d.growthPreview != null,
  );
  return needsGrowth ? AiNannyConfirmMode.allPossible : AiNannyConfirmMode.completeOnly;
}

/// Persiste registros após confirmação explícita.
class AiNannyRecordConfirmFlow {
  AiNannyRecordConfirmFlow({AiNannyRecordActions? actions})
      : _actions = actions ?? AiNannyRecordActions();

  final AiNannyRecordActions _actions;

  /// Grava imediatamente rascunhos completos (ex.: mamada após informar duração).
  Future<AiNannyDraftsPersistResult> persistCompleteDrafts({
    required List<AiNannyRecordDraft> drafts,
    required S strings,
    String transcript = '',
  }) async {
    final babyName =
        (CurrentBabyController.instance.currentBabyRow?['name'] as String?)
                ?.trim() ??
            '';
    final expanded = BreastfeedingBothHelper.expandDrafts(
      drafts,
      strings: strings,
      sourceText: transcript,
    );
    final remaining = <AiNannyRecordDraft>[];
    final confirmations = <String>[];
    final errors = <String>[];
    var saved = 0;

    for (final draft in expanded) {
      final isGrowthReady = draft.status == AiNannyRecordDraftStatus.needsConfirm &&
          draft.growthPreview != null;
      final isRoutineComplete = draft.status == AiNannyRecordDraftStatus.complete;
      if ((!isRoutineComplete && !isGrowthReady) ||
          draft.structured.missingFields.isNotEmpty ||
          BreastfeedingBothHelper.shouldSplit(draft.structured)) {
        remaining.add(draft);
        continue;
      }
      final interp = _interpretationForDraft(draft);
      if (interp == null) {
        remaining.add(draft);
        continue;
      }
      final result = await _actions.applyInterpretation(
        interp,
        transcript: transcript,
        strings: strings,
      );
      if (result.success) {
        saved++;
        confirmations.add(
          AiNannyRecordActions.buildSuccessConfirmation(
            interpretation: interp,
            babyName: babyName,
            strings: strings,
            transcript: transcript,
          ),
        );
      } else {
        errors.add(
          strings.aiPartialSaveRecordFailed(
            AiNannyStructuredClarification.recordTitle(draft.structured, strings),
            result.error ?? strings.aiBreastfeedingSaveFailed,
          ),
        );
        remaining.add(draft);
      }
    }

    return AiNannyDraftsPersistResult(
      remainingDrafts: remaining,
      confirmationLines: confirmations,
      errors: errors,
      savedCount: saved,
    );
  }

  Future<AiNannyConfirmSaveResult> saveFromBundle({
    required AiNannyRecordsBundle bundle,
    required S strings,
    required AiNannyConfirmMode mode,
    String transcript = '',
  }) async {
    final babyId = CurrentBabyController.instance.currentBabyId;
    if (babyId == null) {
      return AiNannyConfirmSaveResult(
        errors: [strings.aiRecordSaveFailed],
      );
    }

    var saved = 0;
    final errors = <String>[];
    final confirmations = <String>[];
    final pendingIncomplete = <AiNannyStructuredRecord>[];
    final remainingDrafts = <AiNannyRecordDraft>[];
    final savedLabels = <String>[];
    final pendingLabels = <String>[];

    final drafts = BreastfeedingBothHelper.expandDrafts(
      bundle.drafts,
      strings: strings,
      sourceText: transcript.isNotEmpty ? transcript : bundle.userMessage,
    );

    for (final draft in drafts) {
      final growthReady = draft.status == AiNannyRecordDraftStatus.needsConfirm &&
          draft.growthPreview != null;
      if (draft.status == AiNannyRecordDraftStatus.incomplete ||
          BreastfeedingBothHelper.shouldSplit(draft.structured)) {
        pendingIncomplete.add(draft.structured);
        remainingDrafts.add(draft);
        pendingLabels.add(
          _draftStatusLine(draft, strings, saved: false),
        );
        continue;
      }
      if (draft.status == AiNannyRecordDraftStatus.needsConfirm &&
          !growthReady &&
          mode != AiNannyConfirmMode.allPossible) {
        pendingIncomplete.add(draft.structured);
        remainingDrafts.add(draft);
        pendingLabels.add(
          _draftStatusLine(draft, strings, saved: false),
        );
        continue;
      }

      final interp = _interpretationForDraft(draft);
      if (interp == null) {
        pendingIncomplete.add(draft.structured);
        remainingDrafts.add(draft);
        pendingLabels.add(
          _draftStatusLine(draft, strings, saved: false),
        );
        continue;
      }

      final result = await _actions.applyInterpretation(
        interp,
        transcript: transcript.isNotEmpty ? transcript : bundle.userMessage,
        strings: strings,
      );
      if (result.success) {
        saved++;
        final babyName =
            (CurrentBabyController.instance.currentBabyRow?['name'] as String?)
                    ?.trim() ??
                '';
        confirmations.add(
          AiNannyRecordActions.buildSuccessConfirmation(
            interpretation: interp,
            babyName: babyName,
            strings: strings,
            transcript: transcript.isNotEmpty ? transcript : bundle.userMessage,
          ),
        );
        savedLabels.add(_draftStatusLine(draft, strings, saved: true));
      } else {
        final label = AiNannyStructuredClarification.recordTitle(
          draft.structured,
          strings,
        );
        errors.add(
          strings.aiPartialSaveRecordFailed(label, result.error ?? ''),
        );
        pendingIncomplete.add(draft.structured);
        remainingDrafts.add(draft);
        pendingLabels.add(
          _draftStatusLine(draft, strings, saved: false),
        );
      }
    }

    AiNannyRecordsBundle? remainingBundle;
    if (remainingDrafts.isNotEmpty) {
      remainingBundle = AiNannyStructuredMapper.prepareBundle(
        bundle: AiNannyRecordsBundle(
          drafts: remainingDrafts,
          userMessage: bundle.userMessage,
          usedExtractionFallback: bundle.usedExtractionFallback,
        ),
        strings: strings,
      );
      final interps = pendingIncomplete
          .map(AiNannyStructuredMapper.toInterpretation)
          .whereType<VoiceRecordInterpretation>()
          .toList();
      if (interps.isNotEmpty) {
        PendingRoutineRecordStore.instance.set(
          babyId: babyId,
          events: interps,
          originalTranscript: bundle.userMessage,
        );
      }
    } else {
      PendingRoutineRecordStore.instance.clear();
    }

    String? statusSummary;
    if (saved > 0 && pendingLabels.isNotEmpty) {
      statusSummary = buildPartialStatusSummary(
        savedLines: savedLabels,
        pendingLines: pendingLabels,
        errors: errors,
        strings: strings,
      );
    }

    return AiNannyConfirmSaveResult(
      savedCount: saved,
      pendingIncomplete: pendingIncomplete,
      errors: errors,
      confirmationLines: confirmations,
      remainingBundle: remainingBundle,
      statusSummary: statusSummary,
    );
  }

  static String _draftStatusLine(
    AiNannyRecordDraft draft,
    S strings, {
    required bool saved,
  }) {
    final title = AiNannyStructuredClarification.recordTitle(
      draft.structured,
      strings,
    );
    if (saved) {
      final detail = draft.understoodLines.isNotEmpty
          ? draft.understoodLines.first.replaceFirst('• ', '')
          : title;
      return strings.aiPartialSaveLineSaved(detail);
    }
    if (draft.structured.missingFields.contains('durationMinutes') &&
        draft.structured.type == 'feeding') {
      final side = '${draft.structured.fields['breastSide'] ?? ''}';
      if (side == 'left' || side == 'right') {
        final sideLabel = side == 'left'
            ? strings.aiRecordSideLeft
            : strings.aiRecordSideRight;
        return strings.aiPartialSaveLineBreastNeedsDuration(title, sideLabel);
      }
      return strings.aiPartialSaveLineNeedsInfo(title);
    }
    return strings.aiPartialSaveLineNeedsInfo(title);
  }

  static String buildPartialStatusSummary({
    required List<String> savedLines,
    required List<String> pendingLines,
    required List<String> errors,
    required S strings,
  }) {
    final buf = StringBuffer()..writeln(strings.aiPartialSaveSummaryHeader);
    for (final line in savedLines) {
      buf.writeln('✅ $line');
    }
    for (final line in pendingLines) {
      buf.writeln('⚠️ $line');
    }
    if (errors.isNotEmpty) {
      buf.writeln();
      for (final e in errors) {
        buf.writeln(e);
      }
    }
    return buf.toString().trim();
  }

  VoiceRecordInterpretation? _interpretationForDraft(AiNannyRecordDraft draft) {
    if (draft.growthPreview != null) {
      final g = draft.growthPreview!;
      if (g.measurementType == 'weight') {
        return VoiceRecordInterpretation(
          type: 'weight',
          summary: 'Peso ${g.newValue} kg',
          weight: VoiceWeightPayload(
            weightKg: g.newValue,
            measuredAt: DateTime.now(),
          ),
        );
      }
      return VoiceRecordInterpretation(
        type: 'height',
        summary: 'Altura ${g.newValue} cm',
        height: VoiceHeightPayload(
          heightCm: g.newValue,
          measuredAt: DateTime.now(),
        ),
      );
    }
    return AiNannyStructuredMapper.toInterpretation(draft.structured);
  }

  static String buildClarificationFromBundle(AiNannyRecordsBundle bundle, S s) {
    final explained = PendingRecordsExplanation.buildPendingRecordsExplanation(
      bundle: bundle,
      strings: s,
    );
    if (explained != null && explained.isNotEmpty) return explained;

    final structured =
        AiNannyStructuredClarification.buildClarificationForBundle(bundle, s);
    if (structured.trim().isNotEmpty) return structured;

    final incomplete = bundle.drafts
        .where((d) => d.status == AiNannyRecordDraftStatus.incomplete)
        .map((d) => d.structured)
        .toList();
    if (incomplete.isEmpty) return '';
    final interps = incomplete
        .map(AiNannyStructuredMapper.toInterpretation)
        .whereType<VoiceRecordInterpretation>()
        .toList();
    return buildClarificationPrompt(interps, bundle.userMessage, s);
  }
}
