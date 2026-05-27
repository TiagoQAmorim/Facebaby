import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/models/ai/ai_nanny_parsed_message.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_local_message_parser.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_clarification.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_mapper.dart';
import 'package:facebaby_flutter/services/ai/detected_record_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const s = S(AppLang.pt);

  test('dormiu 72 minutos às 18:03 fica completo', () {
    const msg = 'ela dormiu por 72 minutos às 18:03';
    final parse = AiNannyLocalMessageParser.parse(msg);
    expect(parse.hasRecords, isTrue);
    final rec = parse.records.firstWhere((r) => r.type == 'sleep');
    final enforced = AiNannyStructuredClarification.enforce(rec, msg);
    expect(enforced.missingFields, isEmpty);
    expect(enforced.fields['durationMinutes'], 72);
    expect(enforced.fields['action'], 'complete');

    final detected = DetectedRecordBuilder.fromStructured(enforced, s);
    expect(
      detected.missingLines.any((l) => l.contains('sleepStatus')),
      isFalse,
    );
    expect(
      detected.missingLines.any((l) => l.contains('startedAt')),
      isFalse,
    );
  });

  test('display line de sono não mostra tipo sleep cru', () {
    const msg = 'dormiu 40 minutos';
    final parse = AiNannyLocalMessageParser.parse(msg);
    final bundle = AiNannyStructuredMapper.prepareBundle(
      bundle: AiNannyStructuredMapper.buildBundle(
        parse: parse,
        userMessage: msg,
        strings: s,
      ),
      strings: s,
    );
    final line = bundle.drafts.first.displayLine.toLowerCase();
    expect(line, isNot(contains('sleepstatus')));
    expect(line, contains('40'));
  });
}
