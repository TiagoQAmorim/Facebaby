import 'package:flutter/foundation.dart';

import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_message_model.dart';
import '../../models/ai/voice_record_interpretation.dart';
import '../../repositories/ai/ai_chat_repository.dart';
import '../../utils/voice_intent.dart';
import '../../utils/voice_record_infer.dart';
import 'voice_record_api_service.dart';
import 'voice_record_save_service.dart';

/// Resultado ao registrar rotina a partir de texto no chat (sem askAiNanny).
class TextRecordApplyResult {
  const TextRecordApplyResult({
    required this.confirmationText,
    required this.saveKind,
  });

  final String confirmationText;
  final VoiceRecordSaveKind saveKind;
}

/// Interpreta mensagem do chat e persiste registro (sono, mamada, etc.).
class TextRecordApplyService {
  TextRecordApplyService({
    VoiceRecordApiService? api,
    VoiceRecordSaveService? save,
    AiChatRepository? repository,
  })  : _api = api ?? VoiceRecordApiService(),
        _save = save ?? VoiceRecordSaveService(),
        _repository = repository ?? AiChatRepository();

  final VoiceRecordApiService _api;
  final VoiceRecordSaveService _save;
  final AiChatRepository _repository;

  /// Retorna null se a mensagem deve ir para a IA Babá (pergunta / conversa).
  Future<TextRecordApplyResult?> tryApply({
    required String text,
    required S strings,
    required AppLang locale,
    String? babyName,
    String? babyCloudId,
    String? userId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (!_looksLikeRegisterIntent(trimmed)) return null;

    var interp = enhanceVoiceRecordInterpretation(
      interpretation: const VoiceRecordInterpretation.unknown(),
      transcript: trimmed,
    );

    final needsCloud =
        !interp.canRegister ||
        interpretationShouldAskAi(type: interp.type, transcript: trimmed);

    if (needsCloud && _shouldTryCloudInterpret(trimmed)) {
      try {
        final remote = await _api.processText(
          transcript: trimmed,
          babyName: babyName,
          locale: locale,
        );
        interp = enhanceVoiceRecordInterpretation(
          interpretation: remote.interpretation,
          transcript: trimmed,
        );
      } catch (e, st) {
        debugPrint('TextRecordApplyService: processText falhou: $e\n$st');
        if (!interp.canRegister) return null;
      }
    }

    if (!interp.canRegister) return null;
    if (interpretationShouldAskAi(type: interp.type, transcript: trimmed)) {
      return null;
    }

    final applyResult = await _save.applyConfirmed(
      interpretation: interp,
      transcript: trimmed,
    );
    final kind = applyResult.kind;

    final confirmation = _confirmationFor(kind, strings);
    await _appendChat(
      userText: trimmed,
      assistantText: confirmation,
      babyCloudId: babyCloudId,
      userId: userId,
    );

    return TextRecordApplyResult(
      confirmationText: confirmation,
      saveKind: kind,
    );
  }

  bool _looksLikeRegisterIntent(String t) {
    final low = t.toLowerCase();
    if (low.contains('registr')) return true;

    final local = enhanceVoiceRecordInterpretation(
      interpretation: const VoiceRecordInterpretation.unknown(),
      transcript: t,
    );
    if (local.canRegister && !transcriptLooksLikeQuestion(t)) return true;

    if (transcriptLooksLikeQuestion(t)) return false;

    const cues = [
      'mamou',
      'mamei',
      'fralda',
      'trocou',
      'pesou',
      'sono',
      'soneca',
      'dormiu',
      'dormir',
      'dormindo',
      'acordou',
      'febre',
      'vacin',
      'consulta',
      'altura',
      ' cm',
      ' kg',
    ];
    return cues.any(low.contains);
  }

  bool _shouldTryCloudInterpret(String t) {
    if (t.toLowerCase().contains('registr')) return true;
    final local = enhanceVoiceRecordInterpretation(
      interpretation: const VoiceRecordInterpretation.unknown(),
      transcript: t,
    );
    return !local.canRegister;
  }

  String _confirmationFor(VoiceRecordSaveKind kind, S s) {
    return switch (kind) {
      VoiceRecordSaveKind.sleepStarted => s.aiChatSleepStartedConfirm,
      VoiceRecordSaveKind.sleepEnded => s.aiChatSleepEndedConfirm,
      VoiceRecordSaveKind.saved => s.aiChatRegisterSavedConfirm,
    };
  }

  Future<void> _appendChat({
    required String userText,
    required String assistantText,
    String? babyCloudId,
    String? userId,
  }) async {
    final now = DateTime.now();
    await _repository.add(
      AiMessage(
        id: AiMessage.newId(),
        text: userText,
        sender: AiMessageSender.user,
        status: AiMessageStatus.sent,
        createdAt: now,
        babyId: babyCloudId,
        userId: userId,
      ),
    );
    await _repository.add(
      AiMessage(
        id: AiMessage.newId(),
        text: assistantText,
        sender: AiMessageSender.ai,
        status: AiMessageStatus.sent,
        createdAt: now.add(const Duration(milliseconds: 80)),
        babyId: babyCloudId,
        userId: userId,
      ),
    );
  }
}
