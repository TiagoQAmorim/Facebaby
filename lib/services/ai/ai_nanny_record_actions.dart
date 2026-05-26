import 'package:intl/intl.dart';

import '../../i18n/app_i18n.dart';
import '../../models/ai/voice_record_interpretation.dart';
import 'voice_record_save_service.dart';

/// Ações de registro da IA Babá — única porta para persistir no banco.
class AiNannyRecordActions {
  AiNannyRecordActions({VoiceRecordSaveService? save})
      : _save = save ?? VoiceRecordSaveService();

  final VoiceRecordSaveService _save;

  Future<AiNannySaveResult> createDiaperRecord(
    VoiceRecordInterpretation interpretation,
  ) async =>
      _run(() => _save.applyConfirmed(interpretation: interpretation));

  Future<AiNannySaveResult> createFeedingRecord(
    VoiceRecordInterpretation interpretation,
  ) async =>
      _run(() => _save.applyConfirmed(interpretation: interpretation));

  Future<AiNannySaveResult> createSleepRecord(
    VoiceRecordInterpretation interpretation, {
    String transcript = '',
  }) async =>
      _run(
        () => _save.applyConfirmed(
          interpretation: interpretation,
          transcript: transcript,
        ),
      );

  Future<AiNannySaveResult> createMedicineRecord(
    VoiceRecordInterpretation interpretation,
  ) async =>
      _run(() => _save.applyConfirmed(interpretation: interpretation));

  Future<AiNannySaveResult> createGrowthRecord(
    VoiceRecordInterpretation interpretation,
  ) async =>
      _run(() => _save.applyConfirmed(interpretation: interpretation));

  Future<AiNannySaveResult> createMemoryRecord(
    VoiceRecordInterpretation interpretation,
  ) async =>
      _run(() => _save.applyConfirmed(interpretation: interpretation));

  Future<AiNannySaveResult> applyInterpretation(
    VoiceRecordInterpretation interpretation, {
    String transcript = '',
  }) async =>
      _run(
        () => _save.applyConfirmed(
          interpretation: interpretation,
          transcript: transcript,
        ),
      );

  Future<AiNannySaveResult> _run(
    Future<VoiceRecordSaveKind> Function() action,
  ) async {
    try {
      final kind = await action();
      return AiNannySaveResult(success: true, saveKind: kind);
    } on VoiceRecordSaveException catch (e) {
      return AiNannySaveResult(success: false, error: e.message);
    } catch (e) {
      return AiNannySaveResult(success: false, error: '$e');
    }
  }

  /// Mensagem curta após salvar com dados reais (nunca “vou registrar”).
  static String buildSuccessConfirmation({
    required VoiceRecordInterpretation interpretation,
    required String babyName,
    required S strings,
    DateTime? at,
  }) {
    final name = babyName.trim().isEmpty ? 'o bebê' : babyName.trim();
    final when = DateFormat('HH:mm').format(at ?? DateTime.now());
    final line = _recordLine(interpretation, strings);
    return '🤖 ${strings.aiRecordConfirmedPrefix(name, line, when)}';
  }

  static String _recordLine(
    VoiceRecordInterpretation i,
    S strings,
  ) {
    switch (i.type) {
      case 'diaper':
        final k = (i.diaper?.kind ?? '').toLowerCase();
        return switch (k) {
          'pee' => strings.aiRecordLineDiaperPee,
          'poo' => strings.aiRecordLineDiaperPoo,
          'both' => strings.aiRecordLineDiaperBoth,
          _ => strings.aiRecordLineDiaperGeneric,
        };
      case 'feeding':
        return strings.aiRecordLineFeeding;
      case 'sleep':
        final a = (i.sleep?.action ?? '').toLowerCase();
        if (a == 'start') return strings.aiRecordLineSleepStart;
        if (a == 'end') return strings.aiRecordLineSleepEnd;
        return strings.aiRecordLineSleep;
      case 'weight':
        return strings.aiRecordLineWeight;
      case 'height':
        return strings.aiRecordLineHeight;
      case 'symptom':
        return strings.aiRecordLineSymptom;
      default:
        return strings.aiRecordLineGeneric;
    }
  }

  /// Resposta final do chat: só afirma registro se a action salvou de verdade.
  static String resolveChatAnswer({
    required String? aiAnswer,
    required bool saved,
    required bool needsClarification,
    required String? error,
    required String? confirmation,
    required String? clarificationPrompt,
    required S strings,
  }) {
    final confirm = confirmation?.trim();
    final ai = aiAnswer?.trim();
    final clarify = clarificationPrompt?.trim() ?? '';

    if (saved && !needsClarification && confirm != null && confirm.isNotEmpty) {
      if (ai == null || ai.isEmpty || _shouldReplaceWithConfirmation(ai)) {
        return confirm;
      }
      if (_claimsRegistration(ai)) return confirm;
      return ai;
    }

    if (saved && needsClarification && confirm != null && confirm.isNotEmpty) {
      if (clarify.isNotEmpty) {
        return '$confirm\n\n${_insistentClarificationBubble(ai, clarify, strings)}';
      }
      if (_claimsFullRegistration(ai)) {
        return '$confirm\n\n${strings.aiVoiceNeedClarification}';
      }
      final sanitized = _stripFalseRegistrationClaims(ai);
      if (sanitized.isEmpty) return confirm;
      return '$confirm\n\n$sanitized';
    }

    if (needsClarification && !saved) {
      if (clarify.isNotEmpty) {
        return _insistentClarificationBubble(ai, clarify, strings);
      }
      if (_claimsRegistration(ai)) {
        return strings.aiVoiceNeedClarification;
      }
      if (ai != null && ai.isNotEmpty) return ai;
      return strings.aiVoiceNeedClarification;
    }

    if (error != null && error.trim().isNotEmpty && !saved) {
      if (_claimsRegistration(ai)) return strings.aiRecordSaveFailed;
      if (ai != null && ai.isNotEmpty) {
        return '$ai\n\n${strings.aiRecordSaveFailed}';
      }
      return strings.aiRecordSaveFailed;
    }

    if (!saved && _claimsRegistration(ai)) {
      return strings.aiRecordSaveFailed;
    }

    return ai ?? confirm ?? '';
  }

  /// Compatível com testes legados — delega para [resolveChatAnswer].
  static String preferredChatAnswer({
    required String? aiAnswer,
    required String? confirmation,
    required bool saved,
  }) {
    return resolveChatAnswer(
      aiAnswer: aiAnswer,
      saved: saved,
      needsClarification: false,
      error: null,
      confirmation: confirmation,
      clarificationPrompt: null,
      strings: const S(AppLang.pt),
    );
  }

  static bool _shouldReplaceWithConfirmation(String ai) {
    return _promisesFutureRegistration(ai) || !_mentionsSaved(ai);
  }

  static String _stripFalseRegistrationClaims(String? ai) {
    if (ai == null || ai.trim().isEmpty) return '';
    if (_claimsFullRegistration(ai)) return '';
    return ai;
  }

  static bool _claimsRegistration(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    return _mentionsSaved(text) || _promisesFutureRegistration(text);
  }

  static bool _claimsFullRegistration(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    final low = text.toLowerCase();
    if (_promisesFutureRegistration(text)) return false;
    return low.contains('registrei') ||
        low.contains('registrado') ||
        low.contains('registro criado') ||
        low.contains('salvei no app') ||
        low.contains('anotei') ||
        low.contains('pronto, registrei') ||
        low.contains('já registrei') ||
        low.contains('tudo registrado') ||
        low.contains('já está registrado') ||
        low.contains('foi registrado');
  }

  static bool _promisesFutureRegistration(String text) {
    final low = text.toLowerCase();
    return low.contains('vou registrar') ||
        low.contains('vou anotar') ||
        low.contains('vou salvar') ||
        low.contains('irei registrar') ||
        low.contains('deixa que eu registro') ||
        low.contains('registrando agora');
  }

  static bool _mentionsSaved(String text) {
    final low = text.toLowerCase();
    return low.contains('registrei') ||
        low.contains('registrado') ||
        low.contains('registro criado') ||
        low.contains('salvei') ||
        low.contains('anotei') ||
        low.contains('pronto, registrei');
  }

  /// Garante perguntas obrigatórias na bolha — não só no snackbar.
  static String _insistentClarificationBubble(
    String? aiAnswer,
    String clarificationPrompt,
    S strings,
  ) {
    final questions = clarificationPrompt.trim();
    if (questions.isEmpty) return strings.aiVoiceNeedClarification;

    final ai = aiAnswer?.trim();
    if (_claimsRegistration(ai)) return questions;

    final lead = strings.aiClarifyRegisterNeeded;
    if (ai == null || ai.isEmpty) return '$lead\n\n$questions';

    if (_looksLikeClarificationAsk(ai) && _coversClarificationPoints(ai, questions)) {
      return ai;
    }

    if (_looksLikeClarificationAsk(ai)) {
      return '$ai\n\n$questions';
    }

    return '$lead\n\n$questions';
  }

  static bool _looksLikeClarificationAsk(String text) {
    final low = text.toLowerCase();
    if (!low.contains('?')) return false;
    return low.contains('peito') ||
        low.contains('esquerdo') ||
        low.contains('direito') ||
        low.contains('mamadeira') ||
        low.contains('minut') ||
        low.contains('fralda') ||
        low.contains('xixi') ||
        low.contains('cocô') ||
        low.contains('coco') ||
        low.contains('breast') ||
        low.contains('bottle') ||
        low.contains('minute') ||
        low.contains('diaper') ||
        low.contains('pee') ||
        low.contains('poop');
  }

  /// Verifica se a resposta da IA já cobre os pontos do roteiro de esclarecimento.
  static bool _coversClarificationPoints(String ai, String questions) {
    final aiLow = ai.toLowerCase();
    final chunks = questions
        .split(RegExp(r'[?\n]'))
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.length > 8)
        .toList();
    if (chunks.isEmpty) return false;
    var hits = 0;
    for (final chunk in chunks) {
      final tokens = chunk
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 4)
          .take(3);
      if (tokens.any(aiLow.contains)) hits++;
    }
    return hits >= (chunks.length / 2).ceil();
  }
}

class AiNannySaveResult {
  const AiNannySaveResult({
    required this.success,
    this.saveKind,
    this.error,
  });

  final bool success;
  final VoiceRecordSaveKind? saveKind;
  final String? error;
}
