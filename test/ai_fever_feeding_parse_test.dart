import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_local_message_parser.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_clarification.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_mapper.dart';
import 'package:facebaby_flutter/services/ai/pending_records_explanation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const s = S(AppLang.pt);
  const msg =
      'ela acabou de acordar, ja mamou mas esta com febre';

  test('detecta mamada e febre na mesma frase', () {
    final parse = AiNannyLocalMessageParser.parse(msg);
    expect(parse.hasRecords, isTrue);
    expect(parse.records.any((r) => r.type == 'feeding'), isTrue);
    expect(parse.records.any((r) => r.type == 'health_symptom'), isTrue);
    expect(parse.records.any((r) => r.type == 'sleep'), isFalse);

    final fever = parse.records.firstWhere((r) => r.type == 'health_symptom');
    expect(fever.fields['feverReported'], isTrue);
    expect(fever.missingFields, contains('temperatureCelsius'));

    final feeding = parse.records.firstWhere((r) => r.type == 'feeding');
    expect(feeding.missingFields, contains('breastSide'));
  });

  test('pergunta compacta no chat é uma só, sem lista misturada', () {
    final parse = AiNannyLocalMessageParser.parse(msg);
    final bundle = AiNannyStructuredMapper.prepareBundle(
      bundle: AiNannyStructuredMapper.buildBundle(
        parse: parse,
        userMessage: msg,
        strings: s,
      ),
      strings: s,
    );
    final compact = PendingRecordsExplanation.buildPendingRecordsExplanation(
      bundle: bundle,
      strings: s,
      compactForChat: true,
    );
    expect(compact, isNotNull);
    expect(compact!, isNot(contains('Ainda tenho 2')));
    expect(compact.split('\n').length, lessThan(4));
  });

  test('febre com temperatura fecha sintoma', () {
    const withTemp = 'mamou e febre 38,2';
    final parse = AiNannyLocalMessageParser.parse(withTemp);
    final fever = parse.records.firstWhere((r) => r.type == 'health_symptom');
    final enforced = AiNannyStructuredClarification.enforce(fever, withTemp);
    expect(enforced.missingFields, isEmpty);
    expect((enforced.fields['temperatureCelsius'] as num).toDouble(), closeTo(38.2, 0.1));
  });
}
