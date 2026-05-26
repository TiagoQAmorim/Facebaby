import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/models/ai/voice_record_interpretation.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_intent_parser.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_record_actions.dart';
import 'package:facebaby_flutter/utils/voice_record_clarification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiNannyIntentParser', () {
    test('"ela mijou" detecta fralda/xixi', () {
      final p = AiNannyIntentParser.parse('a bebê mijou');
      expect(p, isNotNull);
      expect(p!.intent, AiRegisterIntent.diaperPee);
      expect(p.interpretation?.type, 'diaper');
      expect(p.interpretation?.diaper?.kind, 'pee');
    });

    test('"fez cocô" detecta fralda/cocô', () {
      final p = AiNannyIntentParser.parse('ela fez cocô');
      expect(p?.intent, AiRegisterIntent.diaperPoop);
      expect(p?.interpretation?.diaper?.kind, 'poo');
    });

    test('"mamou agora" detecta alimentação', () {
      final p = AiNannyIntentParser.parse('mamou agora');
      expect(p?.intent, AiRegisterIntent.feeding);
      expect(p?.interpretation?.type, 'feeding');
    });

    test('"dormiu às 14h" detecta sono', () {
      final p = AiNannyIntentParser.parse('dormiu às 14h');
      expect(p?.intent, isIn([
        AiRegisterIntent.sleepComplete,
        AiRegisterIntent.sleepStart,
        AiRegisterIntent.sleepEnd,
      ]));
      expect(p?.interpretation?.type, 'sleep');
    });

    test('xixi sem troca exige confirmação de troca', () {
      expect(
        diaperNeedsChangeConfirmation('acabou de fazer xixi'),
        isTrue,
      );
      expect(
        diaperNeedsChangeConfirmation('troquei a fralda com xixi'),
        isFalse,
      );
    });

    test('EN: "baby peed" detecta fralda/xixi', () {
      final p = AiNannyIntentParser.parse('the baby peed');
      expect(p?.intent, AiRegisterIntent.diaperPee);
      expect(p?.interpretation?.diaper?.kind, 'pee');
    });

    test('ES: "hizo pipí" detecta fralda/xixi', () {
      final p = AiNannyIntentParser.parse('hizo pipí en el pañal');
      expect(p?.intent, AiRegisterIntent.diaperPee);
    });

    test('ES: "hizo caca" detecta cocô', () {
      final p = AiNannyIntentParser.parse('hizo caca');
      expect(p?.intent, AiRegisterIntent.diaperPoop);
    });

    test('EN: "just fed" detecta alimentação', () {
      final p = AiNannyIntentParser.parse('just fed 120 ml');
      expect(p?.intent, AiRegisterIntent.feeding);
    });

    test('FR: "a fait pipi" detecta xixi', () {
      final p = AiNannyIntentParser.parse('elle a fait pipi');
      expect(p?.intent, AiRegisterIntent.diaperPee);
    });

    test('DE: "hat gepinkelt" detecta xixi', () {
      final p = AiNannyIntentParser.parse('hat gepinkelt');
      expect(p?.intent, AiRegisterIntent.diaperPee);
    });

    test('IT: "ha fatto la cacca" detecta cocô', () {
      final p = AiNannyIntentParser.parse('ha fatto la cacca');
      expect(p?.intent, AiRegisterIntent.diaperPoop);
    });

    test('EN: "slept for 2 hours" detecta sono', () {
      final p = AiNannyIntentParser.parse('slept for 2 hours');
      expect(p?.interpretation?.type, 'sleep');
    });

    test('ES: "tiene fiebre" detecta temperatura', () {
      final p = AiNannyIntentParser.parse('tiene fiebre 38.5');
      expect(p?.intent, AiRegisterIntent.temperature);
    });

    test('"sim" confirma após pergunta de fralda', () {
      expect(transcriptConfirmsAffirmative('sim'), isTrue);
      final merged = applyClarificationsToPending(
        [
          const VoiceRecordInterpretation(
            type: 'diaper',
            summary: 'xixi',
            diaper: VoiceDiaperPayload(kind: 'pee'),
          ),
        ],
        'sim',
      );
      expect(merged.first.diaper?.kind, 'pee');
      expect(
        isRoutineRecordComplete(merged.first, 'fez xixi sim'),
        isTrue,
      );
    });
  });

  group('AiNannyRecordActions.resolveChatAnswer', () {
    test('não mantém promessa de registrar sem salvar', () {
      const ai = 'Vou registrar agora no app para você.';
      const confirm = '🤖 Pronto, registrei fralda com xixi para Maitê às 22:58.';
      final out = AiNannyRecordActions.resolveChatAnswer(
        aiAnswer: ai,
        confirmation: confirm,
        saved: true,
        needsClarification: false,
        error: null,
        clarificationPrompt: null,
        strings: const S(AppLang.pt),
      );
      expect(out, confirm);
      expect(out.toLowerCase(), isNot(contains('vou registrar')));
    });

    test('usa confirmação quando IA não menciona registro salvo', () {
      const ai = 'Entendi, foi xixi na fralda.';
      const confirm = '🤖 Registro criado.';
      final out = AiNannyRecordActions.resolveChatAnswer(
        aiAnswer: ai,
        confirmation: confirm,
        saved: true,
        needsClarification: false,
        error: null,
        clarificationPrompt: null,
        strings: const S(AppLang.pt),
      );
      expect(out, confirm);
    });

    test('bloqueia IA que diz registrou quando não salvou', () {
      const ai = 'Pronto, registrei a fralda com xixi no app.';
      final out = AiNannyRecordActions.resolveChatAnswer(
        aiAnswer: ai,
        saved: false,
        needsClarification: false,
        error: 'sem bebê',
        clarificationPrompt: null,
        confirmation: null,
        strings: const S(AppLang.pt),
      );
      expect(out, const S(AppLang.pt).aiRecordSaveFailed);
      expect(out.toLowerCase(), isNot(contains('registrei')));
    });

    test('pendente de esclarecimento não aceita "registrei"', () {
      const ai = 'Registrei a mamada para você.';
      final out = AiNannyRecordActions.resolveChatAnswer(
        aiAnswer: ai,
        saved: false,
        needsClarification: true,
        error: null,
        confirmation: null,
        clarificationPrompt: 'Foi peito ou mamadeira?',
        strings: const S(AppLang.pt),
      );
      expect(out, 'Foi peito ou mamadeira?');
    });

    test('resposta genérica da IA é substituída pelas perguntas obrigatórias', () {
      const strings = S(AppLang.pt);
      const ai =
          'Que delícia, a Maitê acabou de mamar! Isso é ótimo para o crescimento dela.';
      const clarify =
          'Sobre a mamada: foi peito esquerdo ou direito? Sobre a mamada: quantos minutos durou?';
      final out = AiNannyRecordActions.resolveChatAnswer(
        aiAnswer: ai,
        saved: false,
        needsClarification: true,
        error: null,
        confirmation: null,
        clarificationPrompt: clarify,
        strings: strings,
      );
      expect(out, contains(strings.aiClarifyRegisterNeeded));
      expect(out, contains(strings.aiClarifyBreastSide));
      expect(out, contains(strings.aiClarifyFeedingDuration));
      expect(out, isNot(contains('Que delícia')));
    });
  });

  group('buildClarificationPrompt feeding', () {
    test('mamada no peito pede lado e minutos', () {
      const strings = S(AppLang.pt);
      final event = VoiceRecordInterpretation(
        type: 'feeding',
        summary: 'mamou',
        feeding: VoiceFeedingPayload(
          subtype: 'peito',
          eventTime: DateTime(2026, 1, 1, 12),
        ),
      );
      final prompt = buildClarificationPrompt(
        [event],
        'ela acabou de mamar',
        strings,
      );
      expect(prompt, contains(strings.aiClarifyBreastSide));
      expect(prompt, contains(strings.aiClarifyFeedingDuration));
    });
  });
}
