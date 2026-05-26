import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../models/ai/voice_record_interpretation.dart';
import '../../utils/voice_record_clarification.dart';
import 'ai_nanny_record_actions.dart';
import 'ai_nanny_structured_mapper.dart';
import 'pending_routine_record_store.dart';

/// Resultado após o utilizador confirmar o card de registros.
class AiNannyConfirmSaveResult {
  const AiNannyConfirmSaveResult({
    this.savedCount = 0,
    this.pendingIncomplete = const [],
    this.errors = const [],
    this.confirmationLines = const [],
  });

  final int savedCount;
  final List<AiNannyStructuredRecord> pendingIncomplete;
  final List<String> errors;
  final List<String> confirmationLines;
}

enum AiNannyConfirmMode {
  /// Só registros completos (e deltas confirmados).
  completeOnly,

  /// Completos + deltas de crescimento confirmados.
  allPossible,
}

/// Persiste registros após confirmação explícita.
class AiNannyRecordConfirmFlow {
  AiNannyRecordConfirmFlow({AiNannyRecordActions? actions})
      : _actions = actions ?? AiNannyRecordActions();

  final AiNannyRecordActions _actions;

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

    for (final draft in bundle.drafts) {
      if (draft.status == AiNannyRecordDraftStatus.incomplete) {
        pendingIncomplete.add(draft.structured);
        continue;
      }
      if (draft.status == AiNannyRecordDraftStatus.needsConfirm &&
          mode != AiNannyConfirmMode.allPossible) {
        pendingIncomplete.add(draft.structured);
        continue;
      }

      final interp = _interpretationForDraft(draft);
      if (interp == null) {
        pendingIncomplete.add(draft.structured);
        continue;
      }

      final result = await _actions.applyInterpretation(
        interp,
        transcript: transcript.isNotEmpty ? transcript : bundle.userMessage,
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
          ),
        );
      } else {
        errors.add(result.error ?? strings.aiRecordSaveFailed);
      }
    }

    if (pendingIncomplete.isNotEmpty) {
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

    return AiNannyConfirmSaveResult(
      savedCount: saved,
      pendingIncomplete: pendingIncomplete,
      errors: errors,
      confirmationLines: confirmations,
    );
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
