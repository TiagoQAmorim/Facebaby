import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/models/ai/ai_nanny_parsed_message.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_local_message_parser.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_record_actions.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_clarification.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_mapper.dart';
import 'package:facebaby_flutter/services/ai/pending_records_explanation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const s = S(AppLang.pt);

  AiNannyRecordsBundle bundleFor(String text, {double? lastWeightKg}) {
    final parse = AiNannyLocalMessageParser.parse(text);
    return AiNannyStructuredMapper.prepareBundle(
      bundle: AiNannyStructuredMapper.buildBundle(
        parse: parse,
        userMessage: text,
        strings: s,
      ),
      strings: s,
      lastWeightKg: lastWeightKg,
    );
  }

  test('Teste 1: vacina sem nome pergunta qual é o nome', () {
    const text = 'Ela vai tomar uma vacina amanhã às 15h';
    final bundle = bundleFor(text);
    expect(bundle.incompleteCount, greaterThan(0));

    final reply = PendingRecordsExplanation.buildPendingRecordsExplanation(
      bundle: bundle,
      strings: s,
    );
    expect(reply, isNotNull);
    expect(reply!.toLowerCase(), contains('nome da vacina'));
    expect(reply, isNot(contains('Antes de continuar')));
  });

  test('Teste 2: delta de peso sem último peso pede baseline', () {
    const text = 'Ganhou 200 gramas';
    final bundle = bundleFor(text, lastWeightKg: null);
    final reply = PendingRecordsExplanation.buildPendingRecordsExplanation(
      bundle: bundle,
      strings: s,
    );
    expect(reply, isNotNull);
    expect(reply!.toLowerCase(), contains('último peso'));
  });

  test('Teste 3: estado vazio retorna null', () {
    final empty = const AiNannyRecordsBundle(drafts: [], userMessage: '');
    expect(
      PendingRecordsExplanation.buildPendingRecordsExplanation(
        bundle: empty,
        strings: s,
      ),
      isNull,
    );
    expect(PendingRecordsExplanation.hasRealPending(bundle: empty), isFalse);
  });

  test('fallbackRetry não devolve frase genérica', () {
    expect(PendingRecordsExplanation.fallbackRetry(s), isEmpty);
  });

  test('Teste 4: após registros completos não aparece mensagem genérica', () {
    final completeMsg = s.aiActionFirstAllComplete(1);
    final out = AiNannyRecordActions.resolveChatAnswer(
      aiAnswer: completeMsg,
      saved: true,
      needsClarification: true,
      error: null,
      confirmation: 'Salvei fralda.',
      clarificationPrompt: '',
      strings: s,
      pendingBundle: const AiNannyRecordsBundle(drafts: [], userMessage: ''),
    );
    expect(out.toLowerCase(), isNot(contains('antes de continuar')));
    expect(out.toLowerCase(), isNot(contains('finalizar estes registros')));
    expect(out.toLowerCase(), isNot(contains('dizer de novo')));
  });

  test('Teste 5: ganhou 200g com último peso calcula preview', () {
    const text = 'Ganhou 200 gramas';
    final bundle = bundleFor(text, lastWeightKg: 3.5);
    final draft = bundle.drafts.first;
    expect(draft.growthPreview, isNotNull);

    final reply = PendingRecordsExplanation.buildPendingRecordsExplanation(
      bundle: bundle,
      strings: s,
      lastWeightKg: 3.5,
    );
    expect(reply, isNotNull);
    expect(reply!.toLowerCase(), contains('3,700'));
    expect(reply.toLowerCase(), contains('deseja salvar'));
    expect(reply, isNot(contains('Antes de continuar')));
  });

  test('explicitChatReply nunca devolve mensagem genérica de retry', () {
    const text = 'Ela vai tomar uma vacina amanhã às 15h';
    final bundle = bundleFor(text);
    final reply = AiNannyStructuredClarification.explicitChatReply(
      bundle: bundle,
      strings: s,
    );
    expect(reply.toLowerCase(), isNot(contains('dizer de novo')));
    expect(reply, isNot(contains('Antes de continuar, preciso finalizar')));
    if (bundle.incompleteCount > 0) {
      expect(reply.toLowerCase(), contains('vacina'));
    }
  });
}
