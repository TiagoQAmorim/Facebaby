import 'package:flutter/foundation.dart';

import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../models/ai/voice_record_interpretation.dart';
import '../../utils/voice_record_clarification.dart';
import '../../utils/voice_routine_multi_infer.dart';
import 'ai_nanny_service.dart';
import 'pending_routine_record_store.dart';
import 'pending_record_session_store.dart';
import 'pending_records_explanation.dart';
import 'routine_record_interpreter.dart';
import 'ai_nanny_record_actions.dart';
import 'ai_nanny_record_confirm_flow.dart';
import 'ai_nanny_structured_clarification.dart';
import 'ai_nanny_processing_phase.dart';
import 'ai_nanny_structured_mapper.dart';
import 'ai_nanny_local_message_parser.dart';
import 'ai_nanny_intent_lexicon.dart';
import 'ai_nanny_parse_result_normalizer.dart';
import '../../utils/ai_nanny_parse_normalize.dart';
import '../../utils/growth_baseline.dart';
import 'ai_nanny_orchestrator.dart';
import 'detected_record_builder.dart';
import 'ai_nanny_system_context_service.dart';
import 'ai_conversation_state_repository.dart';
import 'parse_ai_nanny_message_service.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../models/ai/ai_nanny_system_context.dart';
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
    this.showRecordsConfirmSheet = false,
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

  /// Abre o modal de confirmação (só na detecção inicial, não em cada resposta).
  final bool showRecordsConfirmSheet;
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
  final AiConversationStateRepository _conversationState =
      AiConversationStateRepository();

  Future<AiNannyTurnResult> processTurn({
    required String userText,
    required S strings,
    required AppLang locale,
    String? babyName,
    String? babyCloudId,
    String? userId,
    VoiceRecordInterpretation? interpretationHint,
    bool tryRegister = true,
    AiNannyProgressCallback? onProgress,
  }) async {
    final text = userText.trim();
    if (text.isEmpty) {
      return const AiNannyTurnResult();
    }

    final babyId = CurrentBabyController.instance.currentBabyId;
    final sessionStore = PendingRecordSessionStore.instance;

    if (babyId != null) {
      await sessionStore.loadForBaby(babyId);
      if (sessionStore.blocksGenericChat(babyId)) {
        final sessionResult = await sessionStore.handleChatMessage(
          text: text,
          strings: strings,
          babyId: babyId,
          lastWeightKg: await GrowthBaseline.latestWeightKgForCurrentBaby(),
          lastHeightCm: await GrowthBaseline.latestHeightCmForCurrentBaby(),
        );
        if (sessionResult.handled) {
          final action = sessionResult.assistantReply?.trim() ?? '';
          final conv = await _fetchPsychologistReply(
            text: text,
            strings: strings,
            locale: locale,
            babyCloudId: babyCloudId,
            userId: userId,
            pendingRecords: true,
            recordsSaved: sessionResult.recordsSaved,
          );
          return AiNannyTurnResult(
            aiAnswer: _mergeConversationalWithAction(
              conversational: conv,
              action: action,
            ),
            recordsBundle: sessionResult.bundle,
            needsClarification: !sessionResult.readyToConfirm,
            showRecordsConfirmSheet: sessionResult.readyToConfirm,
            registerApplied: sessionResult.recordsSaved,
            registerSnack: sessionResult.recordsSaved
                ? strings.aiVoiceSavedOk
                : null,
            confirmationMessage: sessionResult.recordsSaved ? action : null,
          );
        }
      }
    }

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

    final hasRoutineCue = interpretationHint != null ||
        RoutineRecordInterpreter.transcriptHasRoutineCue(text);

    // 1) Extração estruturada primeiro (registos > conversa motivacional).
    if (tryRegister && babyId != null && hasRoutineCue) {
      final structured = await _structuredRecordsTurn(
        text: text,
        strings: strings,
        locale: locale,
        babyName: babyName,
        babyCloudId: babyCloudId,
        userId: userId,
        tryRegister: tryRegister,
        onProgress: onProgress,
      );
      if (structured != null) return structured;
    }

    if (!hasRoutineCue) {
      final answer = await _nanny.sendMessage(
        question: text,
        babyId: babyCloudId,
        userId: userId,
        locale: locale,
      );
      return AiNannyTurnResult(aiAnswer: answer);
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
    final remaining = saveResult.remainingBundle;
    final clarifyBundle = remaining ?? bundle;
    final clarify = hasIncomplete
        ? (saveResult.statusSummary ??
            AiNannyRecordConfirmFlow.buildClarificationFromBundle(
              clarifyBundle,
              strings,
            ))
        : '';

    String? answer;
    if (saveResult.statusSummary != null &&
        saveResult.statusSummary!.trim().isNotEmpty) {
      answer = saveResult.statusSummary;
    } else if (saveResult.savedCount > 0) {
      answer = saveResult.confirmationLines.join('\n');
    } else if (hasIncomplete) {
      answer = AiNannyStructuredClarification.explicitChatReply(
        bundle: clarifyBundle,
        strings: strings,
        clarificationPrompt: clarify,
      );
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
      pendingBundle: hasIncomplete ? clarifyBundle : null,
    );

    final babyId = CurrentBabyController.instance.currentBabyId;
    if (hasIncomplete && remaining != null && babyId != null) {
      await PendingRecordSessionStore.instance.continueWithBundle(
        bundle: remaining,
        babyId: babyId,
        strings: strings,
        lastWeightKg: await GrowthBaseline.latestWeightKgForCurrentBaby(),
        lastHeightCm: await GrowthBaseline.latestHeightCmForCurrentBaby(),
      );
    } else if (saveResult.savedCount > 0 && !hasIncomplete) {
      await PendingRecordSessionStore.instance.markSaved();
    } else if (!hasIncomplete) {
      await PendingRecordSessionStore.instance.clear(
        reason: 'nothing to save',
      );
    }

    return AiNannyTurnResult(
      aiAnswer: merged.isNotEmpty ? merged : answer,
      registerApplied: saveResult.savedCount > 0,
      registerSnack: saveResult.savedCount > 0 ? strings.aiVoiceSavedOk : null,
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
    bool tryRegister = true,
    AiNannyProgressCallback? onProgress,
  }) async {
    onProgress?.call(AiNannyProcessingPhase.understanding);

    var usedFallback = false;
    AiNannyParseResult parse;
    try {
      parse = await _parseService.parse(
        message: text,
        locale: locale,
        babyName: babyName,
        onProgress: onProgress,
      );
    } catch (_) {
      usedFallback = true;
      parse = AiNannyParseResultNormalizer.normalize(
        AiNannyLocalMessageParser.parse(text),
        text,
      );
    }

    final localParse = AiNannyParseResultNormalizer.normalize(
      AiNannyLocalMessageParser.parse(text),
      text,
    );
    parse = _mergeParseResults(parse, localParse, text);
    if (!parse.hasRecords) return null;

    onProgress?.call(AiNannyProcessingPhase.preparing);

    final babyId = CurrentBabyController.instance.currentBabyId;
    final systemContext =
        await AiNannySystemContextService.load(babyId: babyId);

    parse = AiNannyOrchestrator.enrichParse(
      parse: parse,
      context: systemContext,
      sourceText: text,
    );

    var bundle = await _buildBundle(
      parse,
      text,
      strings,
      usedExtractionFallback: usedFallback,
      systemContext: systemContext,
    );
    if (bundle.drafts.isEmpty) return null;

    bundle = AiNannyStructuredMapper.prepareBundle(
      bundle: bundle,
      strings: strings,
      lastWeightKg: await GrowthBaseline.latestWeightKgForCurrentBaby(),
      lastHeightCm: await GrowthBaseline.latestHeightCmForCurrentBaby(),
      systemContext: systemContext,
    );

    final incomplete = bundle.incompleteCount > 0;

    var actionReply = AiNannyOrchestrator.buildSmartReply(
      bundle,
      systemContext,
      strings,
      compactForChat: incomplete,
    );
    if (bundle.usedExtractionFallback) {
      actionReply = '${strings.aiExtractionFallbackHint}\n\n$actionReply';
    }

    onProgress?.call(AiNannyProcessingPhase.showingResults);

    var registerApplied = false;
    var showSheet = !incomplete;
    String? saveSummary;
    String? saveError;

    if (babyId != null && tryRegister) {
      if (!incomplete) {
        final saveResult = await _confirmFlow.saveFromBundle(
          bundle: bundle,
          strings: strings,
          mode: confirmModeForBundle(bundle),
          transcript: text,
        );
        registerApplied = saveResult.savedCount > 0;
        if (saveResult.confirmationLines.isNotEmpty) {
          saveSummary = saveResult.confirmationLines.join('\n');
        }
        if (saveResult.errors.isNotEmpty) {
          saveError = saveResult.errors.first;
        }
        final stillPending = saveResult.pendingIncomplete.isNotEmpty;
        showSheet = stillPending || (saveResult.savedCount == 0 && !stillPending);
        if (registerApplied && !stillPending) {
          await PendingRecordSessionStore.instance.clear(
            reason: 'structured auto-save complete',
          );
          await _conversationState.clear();
        } else if (stillPending && saveResult.remainingBundle != null) {
          bundle = saveResult.remainingBundle!;
          await PendingRecordSessionStore.instance.continueWithBundle(
            bundle: bundle,
            babyId: babyId,
            strings: strings,
            lastWeightKg: await GrowthBaseline.latestWeightKgForCurrentBaby(),
            lastHeightCm: await GrowthBaseline.latestHeightCmForCurrentBaby(),
          );
        }
      } else {
        final partial = await _confirmFlow.persistCompleteDrafts(
          drafts: bundle.drafts,
          strings: strings,
          transcript: text,
        );
        if (partial.savedCount > 0) {
          registerApplied = true;
          saveSummary = partial.confirmationLines.join('\n');
          if (partial.errors.isNotEmpty) saveError = partial.errors.first;
          bundle = AiNannyRecordsBundle(
            drafts: partial.remainingDrafts,
            userMessage: bundle.userMessage,
            followUpQuestions: DetectedRecordBuilder.followUpsForBundle(
              partial.remainingDrafts,
              strings,
            ),
            usedExtractionFallback: bundle.usedExtractionFallback,
          );
          actionReply = AiNannyOrchestrator.buildSmartReply(
            bundle,
            systemContext,
            strings,
          );
        }
        final session = await PendingRecordSessionStore.instance.createFromBundle(
          bundle: bundle,
          babyId: babyId,
          strings: strings,
          lastWeightKg: await GrowthBaseline.latestWeightKgForCurrentBaby(),
          lastHeightCm: await GrowthBaseline.latestHeightCmForCurrentBaby(),
        );
        await _conversationState.syncFromPendingSession(
          session: session,
          babyId: babyId,
        );
      }
    } else if (babyId != null) {
      if (incomplete) {
        final session =
            await PendingRecordSessionStore.instance.createFromBundle(
          bundle: bundle,
          babyId: babyId,
          strings: strings,
          lastWeightKg: await GrowthBaseline.latestWeightKgForCurrentBaby(),
          lastHeightCm: await GrowthBaseline.latestHeightCmForCurrentBaby(),
        );
        await _conversationState.syncFromPendingSession(
          session: session,
          babyId: babyId,
        );
      } else {
        await PendingRecordSessionStore.instance.clear(
          reason: 'all records complete on extract',
        );
        await _conversationState.clear();
      }
    }

    final recordLine = saveSummary?.trim().isNotEmpty == true
        ? saveSummary!
        : actionReply;
    final hasPending = incomplete &&
        PendingRecordsExplanation.hasRealPending(bundle: bundle);
    final conv = hasPending
        ? null
        : await _fetchPsychologistReply(
            text: text,
            strings: strings,
            locale: locale,
            babyCloudId: babyCloudId,
            userId: userId,
            pendingRecords: incomplete,
            recordsSaved: registerApplied,
          );
    final mergedAnswer = hasPending
        ? recordLine
        : _mergeConversationalWithAction(
            conversational: conv,
            action: recordLine,
          );
    final chatAnswer = AiNannyRecordActions.resolveChatAnswer(
      aiAnswer: mergedAnswer,
      saved: registerApplied,
      needsClarification: incomplete,
      error: saveError,
      confirmation: saveSummary,
      clarificationPrompt: incomplete ? actionReply : null,
      strings: strings,
      pendingBundle: bundle,
    );

    return AiNannyTurnResult(
      aiAnswer: chatAnswer.isNotEmpty ? chatAnswer : mergedAnswer,
      needsClarification: incomplete,
      clarificationPrompt: incomplete ? actionReply : null,
      recordsBundle: bundle,
      showRecordsConfirmSheet: showSheet,
      registerApplied: registerApplied,
      registerSnack: registerApplied ? strings.aiVoiceSavedOk : null,
      registerError: saveError,
      confirmationMessage: saveSummary,
    );
  }

  Future<String?> _fetchPsychologistReply({
    required String text,
    required S strings,
    required AppLang locale,
    String? babyCloudId,
    String? userId,
    bool pendingRecords = false,
    bool recordsSaved = false,
  }) async {
    try {
      return await _nanny.sendMessage(
        question: text,
        agentHint: _psychologistAgentHint(
          strings: strings,
          pendingRecords: pendingRecords,
          recordsSaved: recordsSaved,
        ),
        babyId: babyCloudId,
        userId: userId,
        locale: locale,
      );
    } catch (e) {
      debugPrint('AiNannyTurnService: psychologist reply failed: $e');
      return null;
    }
  }

  static String _psychologistAgentHint({
    required S strings,
    bool pendingRecords = false,
    bool recordsSaved = false,
  }) {
    final buf = StringBuffer()
      ..writeln(
        'Você é psicóloga perinatal no app FaceBaby: acolhedora, objetiva, '
        '2 a 4 frases no máximo. Sem clichês longos nem listas enormes.',
      )
      ..writeln(
        'Pode orientar sobre sono, amamentação e rotina com base no que a família disse.',
      );
    if (recordsSaved) {
      buf.writeln(
        'O app JÁ GRAVOU o registro no diário. Confirme com carinho o que foi salvo.',
      );
    } else if (pendingRecords) {
      buf.writeln(
        'Há dados de rotina pendentes — o app fará perguntas objetivas. '
        'Não faça perguntas de registro nem liste campos. '
        'No máximo uma frase curta de acolhimento (sem interrogações).',
      );
    }
    buf.writeln('Nunca invente peso, altura ou horários não ditos.');
    return buf.toString();
  }

  static String _mergeConversationalWithAction({
    required String? conversational,
    required String action,
  }) {
    final c = conversational?.trim() ?? '';
    final a = action.trim();
    if (c.isEmpty) return a;
    if (a.isEmpty) return c;
    if (c == a) return c;
    return '$c\n\n$a';
  }

  /// União cloud + local — evita perder fralda/mamada quando a cloud devolve incompleto.
  static AiNannyParseResult _mergeParseResults(
    AiNannyParseResult primary,
    AiNannyParseResult local,
    String message,
  ) {
    if (!local.hasRecords) return primary;
    if (!primary.hasRecords) return local;

    final byType = <String, AiNannyStructuredRecord>{};
    for (final r in primary.records) {
      byType[r.type] = r;
    }
    for (final r in local.records) {
      final existing = byType[r.type];
      if (existing == null) {
        byType[r.type] = r;
        continue;
      }
      byType[r.type] = _pickRicherStructuredRecord(existing, r);
    }
    final merged = _dropSpuriousDiaperWhenGrowthPresent(
      byType.values.toList(),
      local,
      message,
    );
    return AiNannyParseResult(
      classification: 'create_records',
      records: merged,
      needsConfirmation: true,
    );
  }

  /// Prefere o registro mais completo (menos `missingFields`, mais campos preenchidos).
  static AiNannyStructuredRecord _pickRicherStructuredRecord(
    AiNannyStructuredRecord a,
    AiNannyStructuredRecord b,
  ) {
    if (a.missingFields.length != b.missingFields.length) {
      return a.missingFields.length < b.missingFields.length ? a : b;
    }
    int score(AiNannyStructuredRecord r) {
      var s = r.fields.length;
      if ('${r.fields['vaccineName'] ?? ''}'.trim().isNotEmpty) s += 3;
      if ('${r.fields['reasonOrSpecialty'] ?? ''}'.trim().isNotEmpty) s += 3;
      if ('${r.fields['value'] ?? ''}'.trim().isNotEmpty) s += 3;
      if ('${r.fields['date'] ?? ''}'.trim().isNotEmpty) s += 2;
      if (r.fields['nextDueDate'] != null || r.fields['nextDueInDays'] != null) {
        s += 4;
      }
      return s;
    }
    return score(a) >= score(b) ? a : b;
  }

  /// Cloud às vezes devolve fralda incompleta em frases de altura/peso.
  static List<AiNannyStructuredRecord> _dropSpuriousDiaperWhenGrowthPresent(
    List<AiNannyStructuredRecord> records,
    AiNannyParseResult local,
    String message,
  ) {
    final low = message.toLowerCase();
    final localGrowth = local.records.any(
      (r) =>
          r.type == 'growth_height' ||
          r.type == 'growth_weight' ||
          AiNannyParseNormalize.parseHeightDeltaCm(message) != null ||
          AiNannyParseNormalize.parseWeightDeltaGrams(message) != null,
    );
    if (!localGrowth) return records;

    final hasDiaperCue = AiNannyIntentLexicon.hasDiaperCue(low) ||
        AiNannyIntentLexicon.hasPeeCue(low) ||
        AiNannyIntentLexicon.hasPooCue(low);

    return records.where((r) {
      if (r.type != 'diaper') return true;
      if (hasDiaperCue) return true;
      final incomplete =
          r.missingFields.contains('pee') || r.missingFields.contains('poop');
      return !incomplete;
    }).toList();
  }

  Future<AiNannyRecordsBundle> _buildBundle(
    AiNannyParseResult parse,
    String text,
    S strings, {
    bool usedExtractionFallback = false,
    AiNannySystemContext? systemContext,
  }) async {
    final babyId = CurrentBabyController.instance.currentBabyId;
    double? lastW;
    double? lastH;
    if (babyId != null) {
      lastW = await GrowthBaseline.latestWeightKg(babyId);
      lastH = await GrowthBaseline.latestHeightCm(babyId);
    }
    return AiNannyStructuredMapper.buildBundle(
      parse: parse,
      userMessage: text,
      strings: strings,
      lastWeightKg: lastW,
      lastHeightCm: lastH,
      usedExtractionFallback: usedExtractionFallback,
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
        strings: strings,
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
        clarificationPrompt: prompt.isNotEmpty ? prompt : null,
        snack: null,
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
