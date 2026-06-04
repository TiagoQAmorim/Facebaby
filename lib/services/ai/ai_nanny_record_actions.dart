import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../models/ai/voice_record_interpretation.dart';
import 'pending_records_explanation.dart';
import '../../utils/voice_record_clarification.dart' show parseFeedingDurationMinutes;
import 'feeding_record_verifier.dart';
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
    S? strings,
  }) async =>
      _run(
        () {
          if (interpretation.type == 'feeding') {
            FeedingRecordVerifier.logSavePayload(
              babyId: CurrentBabyController.instance.currentBabyId ?? -1,
              interpretation: interpretation,
            );
          }
          return _save.applyConfirmed(
            interpretation: interpretation,
            transcript: transcript,
          );
        },
        interpretation: interpretation,
        strings: strings,
      );

  Future<AiNannySaveResult> _run(
    Future<VoiceRecordApplyResult> Function() action, {
    VoiceRecordInterpretation? interpretation,
    S? strings,
  }) async {
    try {
      final apply = await action();
      if (interpretation?.type == 'feeding') {
        final babyId = CurrentBabyController.instance.currentBabyId;
        final feedingId = apply.localFeedingId;
        final s = strings ?? const S(AppLang.pt);
        if (babyId == null || feedingId == null) {
          debugPrint(
            'AiNannySave[feeding]: verify failed — missing babyId or localId',
          );
          return AiNannySaveResult(
            success: false,
            error: s.aiBreastfeedingSaveFailed,
          );
        }
        final ok = await FeedingRecordVerifier.existsInHistory(
          babyId: babyId,
          localFeedingId: feedingId,
        );
        if (!ok) {
          debugPrint(
            'AiNannySave[feeding]: verify failed — id $feedingId not in history',
          );
          return AiNannySaveResult(
            success: false,
            error: s.aiBreastfeedingSaveFailed,
          );
        }
        debugPrint(
          'AiNannySave[feeding]: repository ok verified id=$feedingId',
        );
      }
      return AiNannySaveResult(
        success: true,
        saveKind: apply.kind,
        localFeedingId: apply.localFeedingId,
      );
    } on VoiceRecordSaveException catch (e) {
      debugPrint('AiNannySave: VoiceRecordSaveException ${e.message}');
      return AiNannySaveResult(success: false, error: e.message);
    } catch (e) {
      debugPrint('AiNannySave: error $e');
      return AiNannySaveResult(success: false, error: '$e');
    }
  }

  /// Mensagem curta após salvar com dados reais (nunca “vou registrar”).
  static String buildSuccessConfirmation({
    required VoiceRecordInterpretation interpretation,
    required String babyName,
    required S strings,
    DateTime? at,
    String? transcript,
  }) {
    if (interpretation.type == 'feeding') {
      final breast = _breastfeedingSuccessMessage(interpretation, strings);
      if (breast != null) return breast;
    }
    if (interpretation.type == 'vaccine') {
      final v = interpretation.vaccine;
      final next = v?.nextDueAt;
      final applied = v?.appliedAt;
      final vName = v?.name?.trim() ?? '';
      if (vName.isNotEmpty && next != null && applied == null) {
        final dateLabel = DateFormat.yMd().format(next);
        return '🤖 ${strings.aiVaccineScheduledConfirmed(vName, dateLabel)}';
      }
    }
    final name = babyName.trim().isEmpty ? 'o bebê' : babyName.trim();
    final when = DateFormat('HH:mm').format(at ?? DateTime.now());
    final line = _recordLine(interpretation, strings);
    var msg = '🤖 ${strings.aiRecordConfirmedPrefix(name, line, when)}';
    if (interpretation.type == 'consultation' &&
        _needsConsultationAddress(interpretation, transcript)) {
      msg = '$msg\n\n${strings.aiClarifyAppointmentAddress}';
    }
    return msg;
  }

  static bool _needsConsultationAddress(
    VoiceRecordInterpretation interpretation,
    String? transcript,
  ) {
    final addr = interpretation.consultation?.address?.trim() ?? '';
    if (addr.isNotEmpty) return false;
    return !_transcriptMentionsAddress(transcript);
  }

  static bool _transcriptMentionsAddress(String? transcript) {
    if (transcript == null || transcript.trim().isEmpty) return false;
    final low = transcript.toLowerCase();
    return low.contains('endereço') ||
        low.contains('endereco') ||
        low.contains('endereço do') ||
        low.contains('rua ') ||
        low.contains(' rua') ||
        low.contains('av.') ||
        low.contains('avenida') ||
        low.contains('consultório na') ||
        low.contains('consultorio na') ||
        low.contains('clínica na') ||
        low.contains('clinica na') ||
        RegExp(r'\bcep\b').hasMatch(low) ||
        RegExp(r'\b\d{5}-?\d{3}\b').hasMatch(low);
  }

  static String? _breastfeedingSuccessMessage(
    VoiceRecordInterpretation interpretation,
    S strings,
  ) {
    final f = interpretation.feeding;
    if ((f?.subtype ?? '').toLowerCase() != 'peito') return null;
    final sideCode = (f?.side ?? '').toUpperCase();
    final sideLabel = switch (sideCode) {
      'E' => strings.aiRecordSideLeft,
      'D' => strings.aiRecordSideRight,
      _ => null,
    };
    if (sideLabel == null) return null;
    final mins = _feedingDurationMinutes(f?.note);
    if (mins == null) return null;
    return strings.aiBreastfeedingSavedSuccess(sideLabel, mins);
  }

  static int? _feedingDurationMinutes(String? note) {
    if (note == null || note.trim().isEmpty) return null;
    return parseFeedingDurationMinutes(note.toLowerCase()) ??
        int.tryParse(note.replaceAll(RegExp(r'[^0-9]'), ''));
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
      case 'consultation':
        final title = i.consultation?.title?.trim() ?? '';
        if (title.isNotEmpty) {
          return strings.aiRecordLineConsultation(title);
        }
        return strings.aiRecordLineConsultationGeneric;
      case 'vaccine':
        final vaccineName = i.vaccine?.name?.trim() ?? '';
        if (vaccineName.isNotEmpty) {
          return strings.aiRecordLineVaccine(vaccineName);
        }
        return strings.aiRecordLineVaccineGeneric;
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
    AiNannyRecordsBundle? pendingBundle,
  }) {
    final confirm = confirmation?.trim();
    final ai = aiAnswer?.trim();
    final clarify = clarificationPrompt?.trim() ?? '';
    String pendingFallback() {
      final explained = pendingBundle != null
          ? PendingRecordsExplanation.buildPendingRecordsExplanation(
              bundle: pendingBundle,
              strings: strings,
            )
          : null;
      if (explained != null && explained.isNotEmpty) return explained;
      return PendingRecordsExplanation.fallbackRetry(strings);
    }

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
        final extra = pendingFallback();
        return extra.isEmpty ? confirm : '$confirm\n\n$extra';
      }
      final sanitized = _stripFalseRegistrationClaims(ai);
      if (sanitized.isEmpty) return confirm;
      return '$confirm\n\n$sanitized';
    }

    if (needsClarification && !saved) {
      if (clarify.isNotEmpty) {
        return _insistentClarificationBubble(ai, clarify, strings);
      }
      if (ai != null && ai.isNotEmpty && !_claimsRegistration(ai)) {
        return ai;
      }
      return pendingFallback();
    }

    if (!saved &&
        pendingBundle != null &&
        pendingBundle.allRequiredFilled &&
        pendingBundle.confirmCount > 0) {
      final explained = PendingRecordsExplanation.buildPendingRecordsExplanation(
        bundle: pendingBundle,
        strings: strings,
      );
      if (explained != null && explained.isNotEmpty) return explained;
      if (ai != null &&
          ai.isNotEmpty &&
          !_claimsRegistration(ai) &&
          !_impliesRecordsCompleteWithoutSave(ai)) {
        return ai;
      }
      return clarify.isNotEmpty ? clarify : (ai ?? '');
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

    if (!saved && _impliesRecordsCompleteWithoutSave(ai)) {
      if (pendingBundle != null &&
          pendingBundle.allRequiredFilled &&
          pendingBundle.confirmCount > 0) {
        final explained = PendingRecordsExplanation.buildPendingRecordsExplanation(
          bundle: pendingBundle,
          strings: strings,
        );
        if (explained != null && explained.isNotEmpty) return explained;
      }
      final explained = pendingBundle != null
          ? PendingRecordsExplanation.buildPendingRecordsExplanation(
              bundle: pendingBundle,
              strings: strings,
            )
          : null;
      if (explained != null && explained.isNotEmpty) return explained;
      if (error != null && error.trim().isNotEmpty) return error;
      return strings.aiRecordSaveFailed;
    }

    return ai ?? confirm ?? '';
  }

  static bool _impliesRecordsCompleteWithoutSave(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    final low = text.toLowerCase();
    return low.contains('registros estão completos') ||
        low.contains('records are complete') ||
        low.contains('os registros estao completos');
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
    if (questions.isEmpty) {
      return PendingRecordsExplanation.fallbackRetry(strings);
    }

    final ai = aiAnswer?.trim();
    if (_claimsRegistration(ai)) return questions;

    if (ai == null || ai.isEmpty) return questions;

    if (_looksLikeClarificationAsk(ai) && _coversClarificationPoints(ai, questions)) {
      return ai;
    }

    if (_looksLikeClarificationAsk(ai)) {
      return questions;
    }

    return questions;
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
        low.contains('poop') ||
        low.contains('vacina') ||
        low.contains('vaccine') ||
        low.contains('peso') ||
        low.contains('weight') ||
        low.contains('grama') ||
        low.contains('endereço') ||
        low.contains('endereco') ||
        low.contains('consultório') ||
        low.contains('consultorio');
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
    this.localFeedingId,
  });

  final bool success;
  final VoiceRecordSaveKind? saveKind;
  final String? error;
  final int? localFeedingId;
}
