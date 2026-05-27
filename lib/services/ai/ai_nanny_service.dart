import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_message_model.dart';
import '../../repositories/ai/ai_chat_repository.dart';
import '../../utils/app_tts_locale.dart';
import 'ai_usage_limits_service.dart';

/// Região da Cloud Function `askAiNanny` (deve coincidir com functions/src/ai/askAiNanny.js).
const String aiNannyFunctionsRegion = 'southamerica-east1';

/// Texto temporário quando o fallback local é acionado (erro real na callable).
const String aiNannyFallbackDebugMessage =
    'ERRO: fallback usado. Verifique logs da Cloud Function.';

/// Orquestra chat IA Babá: Cloud Function `askAiNanny` + fallback só em erro.
class AiNannyService {
  AiNannyService({
    AiChatRepository? repository,
    AiUsageLimitsService? usageLimits,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _repository = repository ?? AiChatRepository(),
        _usage = usageLimits ?? AiUsageLimitsService(),
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: aiNannyFunctionsRegion),
        _auth = auth ?? FirebaseAuth.instance {
    _usage.startWatching();
    _repository.watchMessages();
    if (kDebugMode) {
      debugPrint(
        'AiNannyService: FirebaseFunctions region=$aiNannyFunctionsRegion '
        'callable=askAiNanny',
      );
    }
  }

  final AiChatRepository _repository;
  final AiUsageLimitsService _usage;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  final StreamController<bool> _typingController =
      StreamController<bool>.broadcast();

  Stream<List<AiMessage>> watchMessages() => _repository.watchMessages();

  /// Lista actual do chat (overlay + Firestore), para lookup síncrono após enviar.
  List<AiMessage> get messagesSnapshot => _repository.snapshot;

  Stream<bool> watchTyping() => _typingController.stream;

  int get remainingToday => _usage.remainingToday;

  Future<void> ensureWelcomeMessage(String welcomeText) async {
    if (!_repository.isEmpty) return;
    await _repository.add(
      AiMessage(
        id: 'welcome-${DateTime.now().microsecondsSinceEpoch}',
        text: welcomeText,
        sender: AiMessageSender.ai,
        status: AiMessageStatus.sent,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Envia pergunta; retorna o texto da resposta da IA quando obtido com sucesso.
  ///
  /// [question] — texto visível no chat (só o que a mãe digitou).
  /// [agentHint] — instrução interna para o modelo (não aparece na bolha).
  Future<String?> sendMessage({
    required String question,
    String? agentHint,
    String? babyId,
    String? userId,
    AppLang? locale,
    @Deprecated('Fallback usa aiNannyFallbackDebugMessage')
    String? mockReplyText,
  }) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return null;
    final hint = agentHint?.trim();

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('AiNannyService: sendMessage abort — usuário não autenticado');
      throw const AiNannyNotSignedInException();
    }

    if (!_usage.canSendMessage()) {
      throw const AiDailyLimitReachedException();
    }

    final userId_ = userId ?? user.uid;
    final userMessage = AiMessage(
      id: AiMessage.newId(),
      text: trimmed,
      sender: AiMessageSender.user,
      status: AiMessageStatus.sending,
      createdAt: DateTime.now(),
      babyId: babyId,
      userId: userId_,
    );
    await _repository.add(userMessage);
    _typingController.add(true);

    String? aiAnswer;
    try {
      try {
        await user.getIdToken(true);
      } catch (e) {
        debugPrint('AiNannyService: getIdToken warning: $e');
      }

      debugPrint(
        'AiNannyService: httpsCallable(askAiNanny) '
        'region=$aiNannyFunctionsRegion uid=${user.uid} '
        'babyId=${babyId ?? "(auto)"} questionLen=${trimmed.length}',
      );

      final callable = _functions.httpsCallable(
        'askAiNanny',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 120),
        ),
      );
      final lang = locale ?? AppLang.pt;
      final result = await callable.call(
        {
          'question': trimmed,
          if (hint != null && hint.isNotEmpty) 'agentHint': hint,
          if (babyId != null && babyId.isNotEmpty) 'babyId': babyId,
          'locale': appLocaleApiCode(lang),
        },
      );

      final data = _parseCallableData(result.data);
      final answer = '${data['answer'] ?? ''}'.trim();
      final messageId = '${data['messageId'] ?? ''}'.trim();

      debugPrint(
        'AiNannyService: askAiNanny OK messageId=$messageId '
        'answerLen=${answer.length} remainingToday=${data['remainingToday']}',
      );

      final remaining = data['remainingToday'];
      if (remaining is int) {
        _usage.applyServerRemaining(remaining);
      } else if (remaining is num) {
        _usage.applyServerRemaining(remaining.toInt());
      } else {
        await _usage.refreshFromServer();
      }

      await _repository.updateById(
        userMessage.id,
        userMessage.copyWith(status: AiMessageStatus.sent),
      );

      if (answer.isEmpty) {
        debugPrint('AiNannyService: resposta vazia da callable — acionando fallback');
        await _applyErrorFallback(
          userMessage: userMessage,
          babyId: babyId,
          userId: userId_,
          reason: 'Resposta vazia da Cloud Function.',
        );
        throw const AiNannyCallFailedException(
          'Resposta vazia da IA Babá. Tente novamente.',
        );
      }

      await _repository.add(
        AiMessage(
          id: messageId.isNotEmpty ? '$messageId-ai' : AiMessage.newId(),
          text: answer,
          sender: AiMessageSender.ai,
          status: AiMessageStatus.sent,
          createdAt: DateTime.now(),
          babyId: babyId,
          userId: userId_,
        ),
      );
      aiAnswer = answer;
    } on FirebaseFunctionsException catch (e, st) {
      _logFunctionsError(e, st);
      if (e.code == 'resource-exhausted') {
        _typingController.add(false);
        throw const AiDailyLimitReachedException();
      }
      await _applyErrorFallback(
        userMessage: userMessage,
        babyId: babyId,
        userId: userId_,
        reason: e.message ?? e.code,
      );
      throw AiNannyCallFailedException(_formatCallableError(e));
    } catch (e, st) {
      if (e is AiDailyLimitReachedException || e is AiNannyCallFailedException) {
        rethrow;
      }
      debugPrint('AiNannyService: erro inesperado: $e\n$st');
      await _applyErrorFallback(
        userMessage: userMessage,
        babyId: babyId,
        userId: userId_,
        reason: '$e',
      );
      throw AiNannyCallFailedException(
        'Não consegui responder agora. Tente novamente em alguns instantes.',
      );
    } finally {
      _typingController.add(false);
    }
    return aiAnswer;
  }

  static Map<String, dynamic> _parseCallableData(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry('$key', value));
    }
    debugPrint('AiNannyService: tipo inesperado em result.data: ${raw.runtimeType}');
    return {};
  }

  static String _formatCallableError(FirebaseFunctionsException e) {
    final msg = (e.message ?? '').trim();
    if (msg.isNotEmpty) return msg;
    if (e.code == 'not-found') {
      return 'Função askAiNanny não encontrada. Confira o deploy em southamerica-east1.';
    }
    return 'Não consegui responder agora. Tente novamente em alguns instantes.';
  }

  void _logFunctionsError(FirebaseFunctionsException e, StackTrace st) {
    debugPrint(
      'AiNannyService: FirebaseFunctionsException\n'
      '  code: ${e.code}\n'
      '  message: ${e.message}\n'
      '  details: ${e.details}\n'
      '  stack: $st',
    );
  }

  Future<void> _applyErrorFallback({
    required AiMessage userMessage,
    String? babyId,
    String? userId,
    String? reason,
  }) async {
    debugPrint(
      'AiNannyService: FALLBACK ativado'
      '${reason != null ? " — $reason" : ""}',
    );
    await _repository.updateById(
      userMessage.id,
      userMessage.copyWith(status: AiMessageStatus.sent),
    );
    final fallbackText = (reason != null && reason.trim().isNotEmpty)
        ? reason.trim()
        : aiNannyFallbackDebugMessage;
    await _repository.add(
      AiMessage(
        id: AiMessage.newId(),
        text: fallbackText,
        sender: AiMessageSender.ai,
        status: AiMessageStatus.error,
        createdAt: DateTime.now(),
        babyId: babyId,
        userId: userId,
      ),
    );
  }

  /// Apaga toda a conversa (thread) no Firestore.
  Future<int> clearConversation() async {
    final user = _auth.currentUser;
    if (user == null) throw const AiNannyNotSignedInException();

    final result = await _functions.httpsCallable('manageAiNannyChat').call(
      {'action': 'clear'},
    );
    await _repository.resetAfterServerClear();
    final data = result.data;
    if (data is Map) {
      final deleted = data['deleted'];
      if (deleted is int) return deleted;
      if (deleted is num) return deleted.toInt();
    }
    return 0;
  }

  /// Apaga um par pergunta/resposta (um documento).
  Future<bool> deleteExchange(String firestoreDocId) async {
    final id = firestoreDocId.trim();
    if (id.isEmpty) return false;
    final user = _auth.currentUser;
    if (user == null) throw const AiNannyNotSignedInException();

    final result = await _functions.httpsCallable('manageAiNannyChat').call({
      'action': 'delete',
      'messageId': id,
    });
    _repository.removeOverlayPairForDoc(id);
    final data = result.data;
    if (data is Map) return data['deleted'] == true;
    return false;
  }

  /// Poda histórico antigo no servidor (chamada opcional ao abrir o chat).
  Future<void> trimHistoryIfNeeded() async {
    if (_auth.currentUser == null) return;
    try {
      await _functions.httpsCallable('manageAiNannyChat').call(
        {'action': 'trim'},
      );
    } catch (e) {
      debugPrint('AiNannyService: trimHistoryIfNeeded $e');
    }
  }

  /// Mensagem do utilizador no chat (sem chamar askAiNanny).
  Future<void> appendUserMessage(
    String text, {
    String? babyId,
    String? userId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final user = _auth.currentUser;
    if (user == null) throw const AiNannyNotSignedInException();
    await _repository.add(
      AiMessage(
        id: AiMessage.newId(),
        text: trimmed,
        sender: AiMessageSender.user,
        status: AiMessageStatus.sent,
        createdAt: DateTime.now(),
        babyId: babyId,
        userId: userId ?? user.uid,
      ),
    );
  }

  /// Resposta da assistente no chat (extração / confirmação — sem GPT).
  Future<void> appendAssistantMessage(
    String text, {
    String? babyId,
    String? userId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final user = _auth.currentUser;
    if (user == null) throw const AiNannyNotSignedInException();
    await _repository.add(
      AiMessage(
        id: AiMessage.newId(),
        text: trimmed,
        sender: AiMessageSender.ai,
        status: AiMessageStatus.sent,
        createdAt: DateTime.now(),
        babyId: babyId,
        userId: userId ?? user.uid,
      ),
    );
  }

  void setTyping(bool value) => _typingController.add(value);

  Future<void> restoreWelcomeAfterClear(String welcomeText) async {
    await _repository.resetAfterServerClear();
    await ensureWelcomeMessage(welcomeText);
  }

  /// Limpa conversa ao abrir o app (nova sessão) e deixa só a mensagem de boas-vindas.
  Future<void> resetForNewAppSession(String welcomeText) async {
    await _repository.beginSessionReset();
    await ensureWelcomeMessage(welcomeText);
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await clearConversation();
      } catch (e) {
        debugPrint('AiNannyService: resetForNewAppSession clear $e');
      }
    }
    _repository.endSessionReset();
  }

  void dispose() {
    _typingController.close();
    _usage.dispose();
    _repository.dispose();
  }
}

class AiDailyLimitReachedException implements Exception {
  const AiDailyLimitReachedException();
}

class AiNannyNotSignedInException implements Exception {
  const AiNannyNotSignedInException();
}

/// Callable falhou; mensagem de diagnóstico no chat + [userMessage] no SnackBar.
class AiNannyCallFailedException implements Exception {
  const AiNannyCallFailedException([this.userMessage]);

  final String? userMessage;

  @override
  String toString() => userMessage ?? 'AiNannyCallFailedException';
}
