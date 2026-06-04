import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../models/ai/ai_nanny_system_context.dart';
import '../../models/ai/detected_baby_record.dart';
import '../../models/ai/pending_record_session.dart';
import 'ai_nanny_structured_clarification.dart';
import 'pending_records_explanation.dart';
import 'ai_nanny_structured_mapper.dart';
import 'ai_nanny_system_context_service.dart';
import 'breastfeeding_both_helper.dart';
import 'detected_record_builder.dart';
import 'ai_conversation_state_repository.dart';
import 'ai_nanny_record_confirm_flow.dart';
import 'pending_routine_record_store.dart';

/// Sessão pendente de registros — persistida por bebé.
class PendingRecordSessionStore {
  PendingRecordSessionStore._();
  static final PendingRecordSessionStore instance = PendingRecordSessionStore._();

  PendingRecordSession? _active;
  int? _babyId;
  final AiConversationStateRepository _conversationState =
      AiConversationStateRepository();
  final AiNannyRecordConfirmFlow _confirmFlow = AiNannyRecordConfirmFlow();

  static String _prefsKey(int babyId) => 'pending_record_session_v1_$babyId';

  /// Sessão ativa que bloqueia chat genérico até confirmar ou cancelar.
  bool blocksGenericChat([int? babyId]) {
    final bid = babyId ?? CurrentBabyController.instance.currentBabyId;
    if (bid == null || _babyId != bid || _active == null) return false;
    return _active!.blocksGenericChat;
  }

  bool hasActive([int? babyId]) => blocksGenericChat(babyId);

  /// Rascunho pronto para gravar (crescimento, vacina, consulta, etc.).
  bool hasAwaitingConfirm([int? babyId]) {
    final bid = babyId ?? CurrentBabyController.instance.currentBabyId;
    if (bid == null || _babyId != bid || _active == null) return false;
    final s = _active!;
    if (s.status != PendingRecordSessionStatus.readyToConfirm) return false;
    return s.canSave && s.bundle.drafts.isNotEmpty;
  }

  AiNannyRecordsBundle? awaitingConfirmBundle([int? babyId]) {
    if (!hasAwaitingConfirm(babyId)) return null;
    return _active!.bundle;
  }

  PendingRecordSession? get active => _active;

  Future<PendingRecordSession> createFromBundle({
    required AiNannyRecordsBundle bundle,
    required int babyId,
    S? strings,
    double? lastWeightKg,
    double? lastHeightCm,
  }) async {
    AiNannySystemContext? ctx;
    if (strings != null) {
      ctx = await AiNannySystemContextService.load(babyId: babyId);
    }
    final synced = strings != null
        ? AiNannyStructuredMapper.prepareBundle(
            bundle: bundle,
            strings: strings,
            lastWeightKg: lastWeightKg,
            lastHeightCm: lastHeightCm,
            systemContext: ctx,
          )
        : bundle;
    final session = PendingRecordSession(
      sessionId: 'prs_${DateTime.now().millisecondsSinceEpoch}',
      bundle: synced,
      createdAt: DateTime.now(),
      currentQuestionIndex: 0,
      status: bundle.allRequiredFilled
          ? PendingRecordSessionStatus.readyToConfirm
          : PendingRecordSessionStatus.collectingInfo,
    );
    _babyId = babyId;
    _active = session;
    await _persist();
    debugPrint(
      'PendingRecordSession: created sessionId=${session.sessionId} '
      'records=${bundle.drafts.length} questions=${bundle.followUpQuestions.length} '
      'canSave=${session.canSave}',
    );
    if (session.currentQuestion != null) {
      debugPrint(
        'PendingRecordSession: currentQuestion=${session.currentQuestion!.question}',
      );
    }
    return session;
  }

  Future<void> loadForBaby(int babyId) async {
    if (_babyId == babyId && _active != null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey(babyId));
    if (raw == null || raw.isEmpty) {
      _babyId = babyId;
      _active = null;
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _active = PendingRecordSession.fromMap(map);
      _babyId = babyId;
      if (_active != null) {
        if (!PendingRecordsExplanation.hasRealPending(session: _active)) {
          debugPrint(
            'PendingRecordSession: corrupt/empty pending on load — clearing',
          );
          _active = null;
          await prefs.remove(_prefsKey(babyId));
          unawaited(_conversationState.clear());
        } else {
          debugPrint(
            'PendingRecordSession: loaded sessionId=${_active!.sessionId} '
            'canSave=${_active!.canSave} '
            'questions=${_active!.bundle.followUpQuestions.length}',
          );
        }
      }
    } catch (e) {
      debugPrint('PendingRecordSession: load failed $e');
      _active = null;
      _babyId = babyId;
    }
  }

  Future<void> clear({String reason = 'cleared'}) async {
    debugPrint('PendingRecordSession: $reason');
    _active = null;
    unawaited(_conversationState.clear());
    PendingRoutineRecordStore.instance.clear();
    final bid = _babyId;
    if (bid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey(bid));
    }
  }

  /// Remove sessões persistidas de todos os bebés (ex.: ao fechar o app).
  Future<void> clearAllSessions({String reason = 'cleared'}) async {
    debugPrint('PendingRecordSession: clearAll $reason');
    _active = null;
    _babyId = null;
    await _conversationState.clear();
    PendingRoutineRecordStore.instance.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (key.startsWith('pending_record_session_v1_')) {
        await prefs.remove(key);
      }
    }
  }

  Future<PendingRecordSessionChatResult> handleChatMessage({
    required String text,
    required S strings,
    required int babyId,
    double? lastWeightKg,
    double? lastHeightCm,
  }) async {
    await loadForBaby(babyId);
    var session = _active;
    if (session != null && !PendingRecordsExplanation.hasRealPending(session: session)) {
      await clear(reason: 'corrupt pending state on chat');
      return const PendingRecordSessionChatResult(
        handled: false,
        sessionCleared: true,
      );
    }
    if (session == null || !session.blocksGenericChat) {
      return const PendingRecordSessionChatResult(handled: false);
    }

    if (session.status == PendingRecordSessionStatus.readyToConfirm) {
      return PendingRecordSessionChatResult(
        handled: true,
        assistantReply: strings.aiConfirmReadyToSaveVoice,
        bundle: session.bundle,
        readyToConfirm: true,
      );
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return PendingRecordSessionChatResult(
        handled: true,
        assistantReply: _repeatCurrentQuestion(session, strings),
        bundle: session.bundle,
      );
    }

    if (_isCancel(trimmed)) {
      await clear(reason: 'cancelled by user');
      return PendingRecordSessionChatResult(
        handled: true,
        assistantReply: strings.aiPendingSessionCancelled,
        sessionCleared: true,
      );
    }

    if (_wantsRepeatQuestion(trimmed)) {
      return PendingRecordSessionChatResult(
        handled: true,
        assistantReply: _repeatCurrentQuestion(session, strings),
        bundle: session.bundle,
      );
    }

    if (_isUnrelatedDuringCollection(trimmed)) {
      return const PendingRecordSessionChatResult(handled: false);
    }

    var working = session;
    var q = working.currentQuestion;
    if (q == null) {
      working = await _syncFollowUps(
        session: working,
        strings: strings,
        lastWeightKg: lastWeightKg,
        lastHeightCm: lastHeightCm,
      );
      q = working.currentQuestion;
    }

    if (q == null) {
      if (working.canSave) {
        final ready = working.copyWith(
          status: PendingRecordSessionStatus.readyToConfirm,
          currentQuestionIndex: 0,
        );
        await _commit(ready);
        return PendingRecordSessionChatResult(
          handled: true,
          assistantReply: strings.aiConfirmReadyToSaveVoice,
          bundle: ready.bundle,
          readyToConfirm: true,
        );
      }
      debugPrint('PendingRecordSession: no question and cannot save');
      return PendingRecordSessionChatResult(
        handled: true,
        assistantReply: AiNannyStructuredClarification.explicitChatReply(
          bundle: working.bundle,
          strings: strings,
        ),
        bundle: working.bundle,
      );
    }

    if (_isDontKnow(trimmed) && _isRequiredField(q)) {
      return PendingRecordSessionChatResult(
        handled: true,
        assistantReply:
            '${strings.aiPendingRequiredFieldCannotSkip}\n\n${_repeatCurrentQuestion(working, strings)}',
        bundle: working.bundle,
      );
    }

    final fullSource = _fullSourceText(working, trimmed);

    final dualDrafts = BreastfeedingBothHelper.tryApplyDualDurations(
      drafts: working.bundle.drafts,
      sourceText: fullSource,
      strings: strings,
      lastWeightKg: lastWeightKg,
      lastHeightCm: lastHeightCm,
    );
    if (dualDrafts != null) {
      final replies = working.clarificationReplies.isEmpty
          ? trimmed
          : '${working.clarificationReplies} $trimmed';
      final source = _fullSourceText(working, trimmed);
      final persisted = await _persistCompleteDrafts(
        drafts: dualDrafts,
        transcript: source,
        strings: strings,
        lastWeightKg: lastWeightKg,
        lastHeightCm: lastHeightCm,
      );
      final dualBundleAfter = AiNannyRecordsBundle(
        drafts: persisted.remainingDrafts,
        userMessage: working.bundle.userMessage,
        followUpQuestions: DetectedRecordBuilder.followUpsForBundle(
          persisted.remainingDrafts,
          strings,
        ),
        usedExtractionFallback: working.bundle.usedExtractionFallback,
      );
      var nextSession = working.copyWith(
        bundle: dualBundleAfter,
        currentQuestionIndex: 0,
        clarificationReplies: replies,
      );
      if (nextSession.canSave) {
        nextSession = nextSession.copyWith(
          status: PendingRecordSessionStatus.readyToConfirm,
        );
        await _commit(nextSession);
        return PendingRecordSessionChatResult(
          handled: true,
          assistantReply: _replyAfterPersist(
            strings: strings,
            persisted: persisted,
            fallback: strings.aiActionFirstAllComplete(
              nextSession.bundle.drafts.length,
            ),
          ),
          bundle: nextSession.bundle,
          readyToConfirm: true,
          recordsSaved: persisted.anySaved,
        );
      }
      final nextQ = nextSession.currentQuestion;
      await _commit(nextSession);
      return PendingRecordSessionChatResult(
        handled: true,
        assistantReply: _replyAfterPersist(
          strings: strings,
          persisted: persisted,
          nextQuestion: nextQ,
          bundle: nextSession.bundle,
        ),
        bundle: nextSession.bundle,
        recordsSaved: persisted.anySaved,
      );
    }

    final oldRec = working.bundle.drafts[q.recordIndex].structured;
    var updated = DetectedRecordBuilder.applyAnswer(
      rec: oldRec,
      field: q.field,
      value: trimmed,
      sourceText: fullSource,
    );
    if (!_answerMapped(oldRec, updated)) {
      debugPrint(
        'PendingRecordSession: answer not mapped userAnswer="$trimmed" field=${q.field}',
      );
      final explained =
          PendingRecordsExplanation.buildPendingRecordsExplanation(
            bundle: working.bundle,
            strings: strings,
            pendingState: working,
            lastWeightKg: lastWeightKg,
          );
      return PendingRecordSessionChatResult(
        handled: true,
        assistantReply: explained != null && explained.isNotEmpty
            ? explained
            : _repeatCurrentQuestion(working, strings),
        bundle: working.bundle,
      );
    }
    debugPrint(
      'PendingRecordSession: userAnswer="$trimmed" mapped field=${q.field} '
      'recordIndex=${q.recordIndex}',
    );

    var drafts = List<AiNannyRecordDraft>.from(working.bundle.drafts);
    if (q.field == 'breastSide' && updated.fields['breastSide'] == 'both') {
      drafts = BreastfeedingBothHelper.expandAtIndex(
        drafts,
        q.recordIndex,
        resolved: updated,
        strings: strings,
        sourceText: fullSource,
        lastWeightKg: lastWeightKg,
        lastHeightCm: lastHeightCm,
      );
    } else {
      drafts[q.recordIndex] = AiNannyStructuredMapper.draftFromRecord(
        updated,
        strings: strings,
        sourceText: fullSource,
        lastWeightKg: lastWeightKg,
        lastHeightCm: lastHeightCm,
      );
    }

    const nextIndex = 0;

    final replies = working.clarificationReplies.isEmpty
        ? trimmed
        : '${working.clarificationReplies} $trimmed';

    final source = _fullSourceText(working, trimmed);
    final persisted = await _persistCompleteDrafts(
      drafts: drafts,
      transcript: source,
      strings: strings,
      lastWeightKg: lastWeightKg,
      lastHeightCm: lastHeightCm,
    );
    final bundleAfterPersist = AiNannyRecordsBundle(
      drafts: persisted.remainingDrafts,
      userMessage: working.bundle.userMessage,
      followUpQuestions: DetectedRecordBuilder.followUpsForBundle(
        persisted.remainingDrafts,
        strings,
      ),
      usedExtractionFallback: working.bundle.usedExtractionFallback,
    );

    var nextSession = working.copyWith(
      bundle: bundleAfterPersist,
      currentQuestionIndex: nextIndex,
      clarificationReplies: replies,
    );

    debugPrint(
      'PendingRecordSession: updated canSave=${nextSession.canSave} '
      'remainingQuestions=${nextSession.bundle.followUpQuestions.length} '
      'savedNow=${persisted.savedCount}',
    );

    if (nextSession.canSave) {
      nextSession = nextSession.copyWith(
        status: PendingRecordSessionStatus.readyToConfirm,
        currentQuestionIndex: 0,
      );
      await _commit(nextSession);
      return PendingRecordSessionChatResult(
        handled: true,
        assistantReply: _replyAfterPersist(
          strings: strings,
          persisted: persisted,
          fallback: strings.aiActionFirstAllComplete(
            nextSession.bundle.drafts.length,
          ),
        ),
        bundle: nextSession.bundle,
        readyToConfirm: true,
        recordsSaved: persisted.anySaved,
      );
    }

    final nextQ = nextSession.currentQuestion;

    await _commit(nextSession);

    if (nextQ != null) {
      debugPrint('PendingRecordSession: currentQuestion=${nextQ.question}');
    }

    return PendingRecordSessionChatResult(
      handled: true,
      assistantReply: _replyAfterPersist(
        strings: strings,
        persisted: persisted,
        nextQuestion: nextQ,
        bundle: nextSession.bundle,
      ),
      bundle: nextSession.bundle,
      recordsSaved: persisted.anySaved,
    );
  }

  Future<AiNannyDraftsPersistResult> _persistCompleteDrafts({
    required List<AiNannyRecordDraft> drafts,
    required String transcript,
    required S strings,
    double? lastWeightKg,
    double? lastHeightCm,
  }) async {
    final result = await _confirmFlow.persistCompleteDrafts(
      drafts: drafts,
      strings: strings,
      transcript: transcript,
    );
    if (result.savedCount > 0) {
      debugPrint(
        'PendingRecordSession: persisted ${result.savedCount} draft(s) '
        'ids confirmed in feedings table',
      );
    }
    final syncedDrafts = <AiNannyRecordDraft>[];
    for (final d in result.remainingDrafts) {
      syncedDrafts.add(
        AiNannyStructuredMapper.draftFromRecord(
          d.structured,
          strings: strings,
          sourceText: transcript,
          lastWeightKg: lastWeightKg,
          lastHeightCm: lastHeightCm,
        ),
      );
    }
    return AiNannyDraftsPersistResult(
      remainingDrafts: syncedDrafts,
      confirmationLines: result.confirmationLines,
      errors: result.errors,
      savedCount: result.savedCount,
    );
  }

  String _replyAfterPersist({
    required S strings,
    required AiNannyDraftsPersistResult persisted,
    String? fallback,
    AiFollowUpQuestion? nextQuestion,
    AiNannyRecordsBundle? bundle,
  }) {
    final parts = <String>[];
    if (persisted.confirmationLines.isNotEmpty) {
      parts.addAll(persisted.confirmationLines);
    }
    if (persisted.errors.isNotEmpty) {
      parts.add(persisted.errors.first);
    }
    if (nextQuestion != null) {
      parts.add(
        AiNannyStructuredClarification.formatAfterAnswer(
          strings: strings,
          question: nextQuestion,
        ),
      );
    } else if (parts.isEmpty) {
      if (fallback != null && fallback.isNotEmpty) {
        parts.add(fallback);
      } else if (bundle != null) {
        parts.add(
          AiNannyStructuredClarification.explicitChatReply(
            bundle: bundle,
            strings: strings,
          ),
        );
      }
    }
    return parts.join('\n\n').trim();
  }

  Future<PendingRecordSession> _syncFollowUps({
    required PendingRecordSession session,
    required S strings,
    double? lastWeightKg,
    double? lastHeightCm,
  }) async {
    final drafts = List<AiNannyRecordDraft>.from(session.bundle.drafts);
    for (var i = 0; i < drafts.length; i++) {
      drafts[i] = AiNannyStructuredMapper.draftFromRecord(
        drafts[i].structured,
        strings: strings,
        lastWeightKg: lastWeightKg,
        lastHeightCm: lastHeightCm,
      );
    }
    final followUps = DetectedRecordBuilder.followUpsForBundle(drafts, strings);
    final bundle = AiNannyRecordsBundle(
      drafts: drafts,
      userMessage: session.bundle.userMessage,
      followUpQuestions: followUps,
      usedExtractionFallback: session.bundle.usedExtractionFallback,
    );
    final next = session.copyWith(bundle: bundle, currentQuestionIndex: 0);
    await _commit(next);
    return next;
  }

  Future<void> updateBundle(AiNannyRecordsBundle bundle) async {
    final session = _active;
    if (session == null) return;
    final next = session.copyWith(
      bundle: bundle,
      currentQuestionIndex: 0,
      status: bundle.allRequiredFilled
          ? PendingRecordSessionStatus.readyToConfirm
          : PendingRecordSessionStatus.collectingInfo,
    );
    await _commit(next);
    debugPrint('PendingRecordSession: bundle synced canSave=${next.canSave}');
  }

  Future<void> markSaved() async {
    final session = _active;
    if (session == null) return;
    await _commit(
      session.copyWith(status: PendingRecordSessionStatus.saved),
    );
    await clear(reason: 'saved');
  }

  /// Guarda rascunho só com confirmação pendente (ex.: +150 g) para "registra isso".
  Future<void> stashAwaitingConfirm({
    required AiNannyRecordsBundle bundle,
    required int babyId,
    S? strings,
    double? lastWeightKg,
    double? lastHeightCm,
  }) async {
    if (bundle.drafts.isEmpty || bundle.confirmCount == 0) return;
    if (!bundle.allRequiredFilled) return;

    AiNannySystemContext? ctx;
    if (strings != null) {
      ctx = await AiNannySystemContextService.load(babyId: babyId);
    }
    final synced = strings != null
        ? AiNannyStructuredMapper.prepareBundle(
            bundle: bundle,
            strings: strings,
            lastWeightKg: lastWeightKg,
            lastHeightCm: lastHeightCm,
            systemContext: ctx,
          )
        : bundle;

    final next = PendingRecordSession(
      sessionId: _active?.sessionId ?? 'prs_${DateTime.now().millisecondsSinceEpoch}',
      bundle: synced,
      createdAt: _active?.createdAt ?? DateTime.now(),
      currentQuestionIndex: 0,
      status: PendingRecordSessionStatus.readyToConfirm,
    );
    _babyId = babyId;
    _active = next;
    await _persist();
    debugPrint(
      'PendingRecordSession: stashed awaiting confirm '
      'records=${synced.drafts.length} confirm=${synced.confirmCount}',
    );
  }

  /// Mantém só registros ainda incompletos após gravação parcial.
  Future<void> continueWithBundle({
    required AiNannyRecordsBundle bundle,
    required int babyId,
    S? strings,
    double? lastWeightKg,
    double? lastHeightCm,
  }) async {
    if (bundle.drafts.isEmpty) {
      await markSaved();
      return;
    }
    if (bundle.confirmCount > 0 && bundle.incompleteCount == 0) {
      await stashAwaitingConfirm(
        bundle: bundle,
        babyId: babyId,
        strings: strings,
        lastWeightKg: lastWeightKg,
        lastHeightCm: lastHeightCm,
      );
      return;
    }
    if (bundle.allRequiredFilled && bundle.confirmCount == 0) {
      await markSaved();
      return;
    }

    AiNannySystemContext? ctx;
    if (strings != null) {
      ctx = await AiNannySystemContextService.load(babyId: babyId);
    }
    final synced = strings != null
        ? AiNannyStructuredMapper.prepareBundle(
            bundle: bundle,
            strings: strings,
            lastWeightKg: lastWeightKg,
            lastHeightCm: lastHeightCm,
            systemContext: ctx,
          )
        : bundle;

    final sessionId =
        _active?.sessionId ?? 'prs_${DateTime.now().millisecondsSinceEpoch}';
    final next = PendingRecordSession(
      sessionId: sessionId,
      bundle: synced,
      createdAt: _active?.createdAt ?? DateTime.now(),
      currentQuestionIndex: 0,
      clarificationReplies: _active?.clarificationReplies ?? '',
      status: synced.allRequiredFilled
          ? PendingRecordSessionStatus.readyToConfirm
          : PendingRecordSessionStatus.collectingInfo,
    );
    _babyId = babyId;
    _active = next;
    await _persist();
    await _conversationState.syncFromPendingSession(
      session: next,
      babyId: babyId,
    );
    debugPrint(
      'PendingRecordSession: partial continue records=${synced.drafts.length} '
      'questions=${synced.followUpQuestions.length}',
    );
  }

  Future<void> _commit(PendingRecordSession session) async {
    _active = session;
    await _persist();
  }

  Future<void> _persist() async {
    final bid = _babyId;
    final session = _active;
    if (bid == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (session == null ||
        session.status == PendingRecordSessionStatus.cancelled ||
        session.status == PendingRecordSessionStatus.saved) {
      await prefs.remove(_prefsKey(bid));
      return;
    }
    await prefs.setString(_prefsKey(bid), jsonEncode(session.toMap()));
  }

  String _fullSourceText(PendingRecordSession session, String latest) {
    final parts = <String>[
      session.bundle.userMessage,
      if (session.clarificationReplies.isNotEmpty) session.clarificationReplies,
      latest,
    ];
    return parts.join(' ').trim();
  }

  String _repeatCurrentQuestion(PendingRecordSession session, S strings) {
    final explained = PendingRecordsExplanation.buildPendingRecordsExplanation(
      bundle: session.bundle,
      strings: strings,
      pendingState: session,
    );
    if (explained != null && explained.isNotEmpty) return explained;

    final q = session.currentQuestion;
    if (q != null) {
      return AiNannyStructuredClarification.formatFollowUpMessage(
        intro: strings.aiPendingRepeatQuestionIntro,
        question: q,
      );
    }
    if (session.canSave) return strings.aiConfirmReadyToSaveVoice;
    return PendingRecordsExplanation.fallbackRetry(strings);
  }

  bool _answerMapped(
    AiNannyStructuredRecord before,
    AiNannyStructuredRecord after,
  ) {
    if (after.missingFields.length < before.missingFields.length) {
      return true;
    }
    for (final f in before.missingFields) {
      if (!after.missingFields.contains(f)) return true;
    }
    return false;
  }

  bool _isCancel(String t) {
    final low = t.toLowerCase();
    return low == 'cancelar' ||
        low == 'cancel' ||
        low.contains('desistir') ||
        low.contains('cancela');
  }

  bool _wantsRepeatQuestion(String t) {
    final low = t.toLowerCase();
    return low.contains('responder oq') ||
        low.contains('responder o qu') ||
        low.contains('qual pergunta') ||
        low.contains('o que precisa') ||
        low.contains('o que falta') ||
        low.contains('oq falta') ||
        low.contains('não entendi') ||
        low.contains('nao entendi') ||
        low.contains('não entendi') ||
        low == '?' ||
        low == 'oq?' ||
        low == 'o que?';
  }

  /// Mensagens que não parecem resposta — repetir pergunta atual.
  bool _isUnrelatedDuringCollection(String t) {
    final low = t.toLowerCase().trim();
    if (_wantsRepeatQuestion(t)) return true;
    if (low.length > 120) return true;

    // Respostas curtas a campos pendentes (duração, fralda, lado).
    if (RegExp(r'^\d').hasMatch(low)) return false;
    if (low.contains('min') ||
        low.contains('h') ||
        low.contains('xixi') ||
        low.contains('coc') ||
        low.contains('pee') ||
        low.contains('poo') ||
        low.contains('esquer') ||
        low.contains('direit') ||
        low.contains('ambos') ||
        low.contains('peito')) {
      return false;
    }

    if (low.contains('como está') ||
        low.contains('me ajuda') ||
        low.contains('obrigad')) {
      return true;
    }
    return false;
  }

  bool _isDontKnow(String t) {
    final low = t.toLowerCase();
    return low.contains('não sei') ||
        low.contains('nao sei') ||
        low.contains("don't know");
  }

  bool _isRequiredField(AiFollowUpQuestion q) => true;
}

class PendingRecordSessionChatResult {
  const PendingRecordSessionChatResult({
    required this.handled,
    this.assistantReply,
    this.bundle,
    this.sessionCleared = false,
    this.readyToConfirm = false,
    this.recordsSaved = false,
  });

  final bool handled;
  final String? assistantReply;
  final AiNannyRecordsBundle? bundle;
  final bool sessionCleared;
  final bool readyToConfirm;
  /// Pelo menos um rascunho foi gravado e verificado no histórico local.
  final bool recordsSaved;
}
