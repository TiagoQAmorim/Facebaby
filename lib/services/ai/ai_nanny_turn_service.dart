import 'package:flutter/foundation.dart';

import '../../controllers/current_baby_controller.dart';
import '../app_database.dart';
import '../../i18n/app_i18n.dart';
import '../../models/ai/voice_record_interpretation.dart';
import '../../utils/voice_record_clarification.dart';
import '../../utils/voice_routine_multi_infer.dart';
import 'ai_nanny_service.dart';
import 'pending_routine_record_store.dart';
import 'routine_record_interpreter.dart';
import 'ai_nanny_record_actions.dart';
import 'ai_nanny_record_confirm_flow.dart';
import 'ai_nanny_structured_mapper.dart';
import 'parse_ai_nanny_message_service.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import 'voice_record_save_service.dart';

/// Resultado de um turno: resposta da IA + registro automático (se couber).
class AiNannyTurnResult {
  const AiNannyTurnResult({
    this.aiAnswer,
    this.registerApplied = false,
    this.registerSnack,
    this.saveKind,
    this.registerError,
    this.needsClarification = false,
    this.clarificationPrompt,
    this.partialSaveSnack,
    this.confirmationMessage,
    this.recordsBundle,
  });

  final String? aiAnswer;
  final bool registerApplied;
  final String? registerSnack;
  final VoiceRecordSaveKind? saveKind;
  final String? registerError;
  final bool needsClarification;
  final String? clarificationPrompt;
  /// Registro parcial (ex.: fralda salva, mamada ainda pendente).
  final String? partialSaveSnack;
  /// Confirmação com horário real após salvar no banco.
  final String? confirmationMessage;

  /// Registros detectados — exige confirmação no card antes de salvar.
  final AiNannyRecordsBundle? recordsBundle;
}

/// Cada mensagem: interpreta rotina e pede resposta da IA Babá em paralelo.
class AiNannyTurnService {
  AiNannyTurnService({
    AiNannyService? nanny,
    RoutineRecordInterpreter? interpreter,
    VoiceRecordSaveService? save,
    ParseAiNannyMessageService? parseService,
    AiNannyRecordConfirmFlow? confirmFlow,
  })  : _nanny = nanny ?? AiNannyService(),
        _interpreter = interpreter ?? RoutineRecordInterpreter(),
        _save = save ?? VoiceRecordSaveService(),
        _parseService = parseService ?? ParseAiNannyMessageService(),
        _confirmFlow = confirmFlow ?? AiNannyRecordConfirmFlow();

  final AiNannyService _nanny;
  final RoutineRecordInterpreter _interpreter;
  final VoiceRecordSaveService _save;
  final ParseAiNannyMessageService _parseService;
  final AiNannyRecordConfirmFlow _confirmFlow;
  final AiNannyRecordActions _actions = AiNannyRecordActions();

  Future<AiNannyTurnResult> processTurn({
    required String userText,
    required S strings,
    required AppLang locale,
    String? babyName,
    String? babyCloudId,
    String? userId,
    VoiceRecordInterpretation? interpretationHint,
    bool tryRegister = true,
  }) async {
    final text = userText.trim();
    if (text.isEmpty) {
      return const AiNannyTurnResult();
    }

    final babyId = CurrentBabyController.instance.currentBabyId;
    final pending = PendingRoutineRecordStore.instance;

    if (babyId != null && pending.hasPendingFor(babyId)) {
      return _completePending(
        text: text,
        strings: strings,
        locale: locale,
        babyName: babyName,
        babyCloudId: babyCloudId,
        userId: userId,
        tryRegister: tryRegister,
      );
    }

    final needsRoutineInterp = tryRegister &&
        (interpretationHint != null ||
            RoutineRecordInterpreter.transcriptHasRoutineCue(text));

    if (!needsRoutineInterp) {
      final answer = await _nanny.sendMessage(
        question: text,
        babyId: babyCloudId,
        userId: userId,
        locale: locale,
      );
      return AiNannyTurnResult(aiAnswer: answer);
    }

    if (tryRegister && babyId != null) {
      final structured = await _structuredRecordsTurn(
        text: text,
        strings: strings,
        locale: locale,
        babyName: babyName,
        babyCloudId: babyCloudId,
        userId: userId,
      );
      if (structured != null) return structured;
    }

    VoiceRecordInterpretation interp;
    try {
      interp = await _interpreter.interpret(
        transcript: text,
        locale: locale,
        babyName: babyName,
        hint: interpretationHint,
      );
    } catch (e) {
      debugPrint('AiNannyTurnService: interpret failed: $e');
      rethrow;
    }

    RegisterAttempt? reg;
    if (tryRegister && babyId != null) {
      final events = expandRoutineInterpretations(
        primary: interp,
        transcript: text,
      );
      reg = await _tryRegisterAll(
        babyId: babyId,
        events: events,
        transcript: text,
        originalTranscript: text,
        strings: strings,
        babyName: babyName,
        resetPendingReplies: true,
      );
    }

    final agentHint = _agentHintFromAttempt(reg, strings);
    String? answer;
    try {
      answer = await _nanny.sendMessage(
        question: text,
        agentHint: agentHint,
        babyId: babyCloudId,
        userId: userId,
        locale: locale,
      );
    } catch (e) {
      debugPrint('AiNannyTurnService: turn failed: $e');
      rethrow;
    }

    final confirmation = reg?.confirmationMessage;
    final mergedAnswer = AiNannyRecordActions.resolveChatAnswer(
      aiAnswer: answer,
      saved: reg?.applied ?? false,
      needsClarification: reg?.needsClarification ?? false,
      error: reg?.error,
      confirmation: confirmation,
      clarificationPrompt: reg?.clarificationPrompt,
      strings: strings,
    );

    return AiNannyTurnResult(
      aiAnswer: mergedAnswer.isNotEmpty ? mergedAnswer : answer,
      registerApplied: reg?.applied ?? false,
      registerSnack: reg?.snack,
      saveKind: reg?.kind,
      registerError: reg?.error,
      needsClarification: reg?.needsClarification ?? false,
      clarificationPrompt: reg?.clarificationPrompt,
      partialSaveSnack: reg?.snackIfPartial,
      confirmationMessage: confirmation,
    );
  }

  /// Salva após o utilizador confirmar no card (nada é gravado antes disto).
  Future<AiNannyTurnResult> saveAfterConfirmation({
    required AiNannyRecordsBundle bundle,
    required AiNannyConfirmMode mode,
    required S strings,
    required AppLang locale,
    String? babyName,
    String? babyCloudId,
    String? userId,
  }) async {
    final saveResult = await _confirmFlow.saveFromBundle(
      bundle: bundle,
      strings: strings,
      mode: mode,
      transcript: bundle.userMessage,
    );

    final hasIncomplete = saveResult.pendingIncomplete.isNotEmpty;
    final clarify = hasIncomplete
        ? AiNannyRecordConfirmFlow.buildClarificationFromBundle(bundle, strings)
        : '';

    String? answer;
    if (saveResult.savedCount > 0 || hasIncomplete) {
      final hint = saveResult.savedCount > 0
          ? 'O app SALVOU ${saveResult.savedCount} registro(s) após confirmação. '
              '${hasIncomplete ? "Ainda faltam dados de outros registros." : ""}'
          : 'Nada foi salvo ainda.';
      try {
        answer = await _nanny.sendMessage(
          question: bundle.userMessage,
          agentHint: hint,
          babyId: babyCloudId,
          userId: userId,
          locale: locale,
        );
      } catch (e) {
        debugPrint('AiNannyTurnService: post-confirm ai $e');
      }
    }

    final merged = AiNannyRecordActions.resolveChatAnswer(
      aiAnswer: answer,
      saved: saveResult.savedCount > 0,
      needsClarification: hasIncomplete,
      error: saveResult.errors.isNotEmpty ? saveResult.errors.first : null,
      confirmation: saveResult.confirmationLines.isNotEmpty
          ? saveResult.confirmationLines.join('\n')
          : null,
      clarificationPrompt: clarify.isNotEmpty ? clarify : null,
      strings: strings,
    );

    return AiNannyTurnResult(
      aiAnswer: merged.isNotEmpty ? merged : answer,
      registerApplied: saveResult.savedCount > 0,
      registerSnack: saveResult.savedCount > 0
          ? strings.aiVoiceSavedOk
          : (hasIncomplete ? strings.aiVoiceNeedClarification : null),
      registerError:
          saveResult.errors.isNotEmpty ? saveResult.errors.first : null,
      needsClarification: hasIncomplete,
      clarificationPrompt: clarify.isNotEmpty ? clarify : null,
      confirmationMessage: saveResult.confirmationLines.isNotEmpty
          ? saveResult.confirmationLines.first
          : null,
    );
  }

  Future<AiNannyTurnResult?> _structuredRecordsTurn({
    required String text,
    required S strings,
    required AppLang locale,
    String? babyName,
    String? babyCloudId,
    String? userId,
  }) async {
    final parse = await _parseService.parse(
      message: text,
      locale: locale,
      babyName: babyName,
    );
    if (!parse.hasRecords) return null;

    final growth = await _parseService.parse(message: ''); // wasteful - fix
    // Use mapper with growth from parse service - add public method
    final bundle = await _buildBundle(parse, text, strings);

    final clarify =
        AiNannyRecordConfirmFlow.buildClarificationFromBundle(bundle, strings);
    final incomplete = bundle.incompleteCount > 0;
    final count = bundle.drafts.length;

    final agentHint = incomplete
        ? 'Detectei $count registro(s) INCOMPLETO(s). A família verá um card para confirmar. '
            'Faça perguntas objetivas sobre o que falta. Não diga que já salvou. '
            '${clarify.isNotEmpty ? "Falta: $clarify" : ""}'
        : 'Detectei $count registro(s) completos. A família confirmará no card antes de salvar. '
            'Não diga que já registrou.';

    String? answer;
    try {
      answer = await _nanny.sendMessage(
        question: text,
        agentHint: agentHint,
        babyId: babyCloudId,
        userId: userId,
        locale: locale,
      );
    } catch (e) {
      debugPrint('AiNannyTurnService: structured turn ai $e');
      rethrow;
    }

    final mergedAnswer = AiNannyRecordActions.resolveChatAnswer(
      aiAnswer: answer,
      saved: false,
      needsClarification: incomplete,
      error: null,
      confirmation: null,
      clarificationPrompt: clarify.isNotEmpty ? clarify : null,
      strings: strings,
    );

    return AiNannyTurnResult(
      aiAnswer: mergedAnswer.isNotEmpty ? mergedAnswer : answer,
      needsClarification: incomplete,
      clarificationPrompt: clarify.isNotEmpty ? clarify : null,
      registerSnack: incomplete ? strings.aiVoiceNeedClarification : null,
      recordsBundle: bundle,
    );
  }

  Future<AiNannyRecordsBundle> _buildBundle(
    AiNannyParseResult parse,
    String text,
    S strings,
  ) async {
    final babyId = CurrentBabyController.instance.currentBabyId;
    double? lastW;
    double? lastH;
    if (babyId != null) {
      final wRows = await AppDatabase.instance.listGrowthRecords(
        babyId: babyId,
        kind: 'weight',
        limit: 1,
      );
      if (wRows.isNotEmpty) {
        lastW = (wRows.first['value'] as num?)?.toDouble();
      }
      lastW ??= (CurrentBabyController.instance.currentBabyRow?['weight_kg']
              as num?)
          ?.toDouble();
      final hRows = await AppDatabase.instance.listGrowthRecords(
        babyId: babyId,
        kind: 'height',
        limit: 1,
      );
      if (hRows.isNotEmpty) {
        lastH = (hRows.first['value'] as num?)?.toDouble();
      }
      lastH ??= (CurrentBabyController.instance.currentBabyRow?['height_cm']
              as num?)
          ?.toDouble();
    }
    return AiNannyStructuredMapper.buildBundle(
      parse: parse,
      userMessage: text,
      strings: strings,
      lastWeightKg: lastW,
      lastHeightCm: lastH,
    );
  }

  /// Instrução à IA com base no que o app realmente fez (salvou, falhou ou pendente).
  String? _agentHintFromAttempt(RegisterAttempt? reg, S strings) {
    if (reg == null) {
      return 'A família descreveu rotina. O app AINDA NÃO salvou nada. '
          'Não diga que registrou nem "vou registrar".';
    }
    if (reg.error != null &&
        reg.error!.trim().isNotEmpty &&
        !reg.applied) {
      return 'O app TENTOU salvar mas FALHOU (${reg.error}). '
          'Não diga que registrou. Explique com empatia e sugira tentar de novo '
          'ou registrar manualmente.';
    }
    if (reg.needsClarification) {
      final missing = reg.clarificationPrompt?.trim() ?? '';
      if (reg.applied) {
        return 'O app SALVOU PARTE dos dados no banco. Ainda falta completar '
            'outro registro. Não diga que tudo foi registrado. '
            'Inclua na resposta as perguntas que faltam. '
            '${missing.isNotEmpty ? "Pergunte OBRIGATORIAMENTE: $missing" : ""}';
      }
      return 'REGISTRO INCOMPLETO — o app AINDA NÃO salvou. Sua mensagem DEVE '
          'incluir perguntas directas sobre o que falta (não só elogios). '
          'No máximo 1 frase curta de carinho + as perguntas. '
          'Nunca diga que já registrou nem "vou registrar". '
          '${missing.isNotEmpty ? "Pergunte OBRIGATORIAMENTE: $missing" : ""}';
    }
    if (reg.applied) {
      return 'O app JÁ SALVOU no banco de dados com sucesso. Confirme com '
          'carinho o que foi registrado. Não diga "vou registrar" — já está feito.';
    }
    return 'A família descreveu rotina. O app não salvou ainda. '
        'Não afirme que registrou.';
  }

  Future<AiNannyTurnResult> _completePending({
    required String text,
    required S strings,
    required AppLang locale,
    String? babyName,
    String? babyCloudId,
    String? userId,
    required bool tryRegister,
  }) async {
    final babyId = CurrentBabyController.instance.currentBabyId!;
    final pending = PendingRoutineRecordStore.instance;

    if (transcriptDeclinesRoutineRegistration(text)) {
      pending.clear();
      final answer = await _nanny.sendMessage(
        question: text,
        babyId: babyCloudId,
        userId: userId,
        locale: locale,
      );
      return AiNannyTurnResult(
        aiAnswer: answer,
        registerSnack: strings.aiRoutineRegisterSkipped,
      );
    }

    pending.appendClarificationReply(text);
    final allReplies = pending.clarificationReplies;
    final merged = applyClarificationsToPending(pending.events, allReplies);

    RegisterAttempt reg = const RegisterAttempt();
    if (tryRegister) {
      reg = await _tryRegisterAll(
        babyId: babyId,
        events: merged,
        transcript: allReplies,
        originalTranscript: pending.originalTranscript,
        strings: strings,
        babyName: babyName,
      );
    }

    final agentHint = _agentHintFromAttempt(reg, strings);
    String? answer;
    try {
      answer = await _nanny.sendMessage(
        question: text,
        agentHint: agentHint,
        babyId: babyCloudId,
        userId: userId,
        locale: locale,
      );
    } catch (e) {
      debugPrint('AiNannyTurnService: pending turn ai failed: $e');
      rethrow;
    }

    final confirmation = reg.confirmationMessage;
    final mergedAnswer = AiNannyRecordActions.resolveChatAnswer(
      aiAnswer: answer,
      saved: reg.applied,
      needsClarification: reg.needsClarification,
      error: reg.error,
      confirmation: confirmation,
      clarificationPrompt: reg.clarificationPrompt,
      strings: strings,
    );

    return AiNannyTurnResult(
      aiAnswer: mergedAnswer.isNotEmpty ? mergedAnswer : answer,
      registerApplied: reg.applied,
      registerSnack: reg.snack,
      saveKind: reg.kind,
      registerError: reg.error,
      needsClarification: reg.needsClarification,
      clarificationPrompt: reg.clarificationPrompt,
      partialSaveSnack: reg.snackIfPartial,
      confirmationMessage: confirmation,
    );
  }

  Future<RegisterAttempt> _tryRegisterAll({
    required int babyId,
    required List<VoiceRecordInterpretation> events,
    required String transcript,
    required S strings,
    String? originalTranscript,
    bool resetPendingReplies = false,
    String? babyName,
  }) async {
    if (events.isEmpty) {
      return const RegisterAttempt();
    }

    final fullTranscript = [
      if (originalTranscript != null && originalTranscript.trim().isNotEmpty)
        originalTranscript.trim(),
      transcript.trim(),
    ].join(' ');

    final stillPending = <VoiceRecordInterpretation>[];
    var applied = 0;
    VoiceRecordSaveKind? lastKind;
    String? firstError;
    final savedTypes = <String>{};
    String? lastConfirmation;

    for (final event in events) {
      if (!isRoutineRecordComplete(event, fullTranscript)) {
        stillPending.add(event);
        continue;
      }

      final saveTranscript = fullTranscript.isNotEmpty ? fullTranscript : transcript;
      final maySave = RoutineRecordMatcher.shouldAutoApply(event, saveTranscript) ||
          isRoutineRecordComplete(event, fullTranscript);
      if (!maySave) continue;

      final result = await _actions.applyInterpretation(
        event,
        transcript: saveTranscript,
      );
      if (!result.success) {
        firstError ??= result.error ?? strings.aiRecordSaveFailed;
        continue;
      }
      lastKind = result.saveKind;
      applied++;
      savedTypes.add(event.type);
      lastConfirmation = AiNannyRecordActions.buildSuccessConfirmation(
        interpretation: event,
        babyName: babyName ?? '',
        strings: strings,
        at: _eventTimestamp(event),
      );
    }

    if (stillPending.isNotEmpty) {
      PendingRoutineRecordStore.instance.set(
        babyId: babyId,
        events: stillPending,
        originalTranscript: originalTranscript ?? transcript,
        resetReplies: resetPendingReplies,
      );
      final prompt =
          buildClarificationPrompt(stillPending, fullTranscript, strings);
      return RegisterAttempt(
        needsClarification: true,
        clarificationPrompt: prompt,
        snack: strings.aiVoiceNeedClarification,
        applied: applied > 0,
        snackIfPartial: applied > 0
            ? _snackForSavedTypes(savedTypes, lastKind, strings)
            : null,
        confirmationMessage: applied > 0 ? lastConfirmation : null,
      );
    }

    PendingRoutineRecordStore.instance.clear();

    if (applied == 0) {
      return RegisterAttempt(applied: false, error: firstError);
    }

    return RegisterAttempt(
      applied: true,
      kind: lastKind,
      snack: _snackForSavedTypes(savedTypes, lastKind, strings),
      confirmationMessage: lastConfirmation,
    );
  }

  DateTime? _eventTimestamp(VoiceRecordInterpretation event) {
    switch (event.type) {
      case 'diaper':
        return event.diaper?.changedAt;
      case 'feeding':
        return event.feeding?.eventTime;
      case 'symptom':
        return event.symptom?.occurredAt;
      default:
        return DateTime.now();
    }
  }

  String _snackForSavedTypes(
    Set<String> types,
    VoiceRecordSaveKind? kind,
    S s,
  ) {
    if (types.contains('feeding') && types.contains('diaper')) {
      return s.aiVoiceSavedFeedingAndDiaper;
    }
    if (types.contains('feeding')) {
      return s.aiVoiceSavedFeeding;
    }
    if (types.contains('symptom')) {
      return s.aiVoiceSavedSymptom;
    }
    return _snackFor(kind, s);
  }

  String _snackFor(VoiceRecordSaveKind? kind, S s) {
    return switch (kind) {
      null => s.aiVoiceSavedOk,
      VoiceRecordSaveKind.sleepStarted => s.aiVoiceSleepStarted,
      VoiceRecordSaveKind.sleepEnded => s.aiVoiceSleepEnded,
      VoiceRecordSaveKind.saved => s.aiVoiceSavedOk,
    };
  }
}

class RegisterAttempt {
  const RegisterAttempt({
    this.applied = false,
    this.kind,
    this.snack,
    this.error,
    this.needsClarification = false,
    this.clarificationPrompt,
    this.snackIfPartial,
    this.confirmationMessage,
  });

  final bool applied;
  final VoiceRecordSaveKind? kind;
  final String? snack;
  final String? error;
  final bool needsClarification;
  final String? clarificationPrompt;
  /// Quando parte dos registros foi salva e ainda falta esclarecer outro.
  final String? snackIfPartial;
  final String? confirmationMessage;
}
