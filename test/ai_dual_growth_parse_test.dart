import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/models/ai/ai_nanny_parsed_message.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_local_message_parser.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_mapper.dart';
import 'package:facebaby_flutter/utils/ai_nanny_parse_normalize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const s = S(AppLang.pt);
  const msg = 'a nenem cresceu 2 centimetros e aumentou 100 gramas';

  test('parseia altura e peso na mesma frase', () {
    expect(AiNannyParseNormalize.parseHeightDeltaCm(msg), 2);
    expect(AiNannyParseNormalize.parseWeightDeltaGrams(msg), 100);

    final parse = AiNannyLocalMessageParser.parse(msg);
    expect(parse.hasRecords, isTrue);
    expect(
      parse.records.any((r) => r.type == 'growth_height'),
      isTrue,
    );
    expect(
      parse.records.any((r) => r.type == 'growth_weight'),
      isTrue,
    );
  });

  test('bundle com dois cards de crescimento e preview', () {
    final parse = AiNannyLocalMessageParser.parse(msg);
    final bundle = AiNannyStructuredMapper.prepareBundle(
      bundle: AiNannyStructuredMapper.buildBundle(
        parse: parse,
        userMessage: msg,
        strings: s,
      ),
      strings: s,
      lastWeightKg: 5.0,
      lastHeightCm: 60.0,
    );
    expect(bundle.drafts.length, 2);
    expect(bundle.confirmCount, 2);
    expect(bundle.allRequiredFilled, isTrue);

    final weight = bundle.drafts.firstWhere(
      (d) => d.structured.type == 'growth_weight',
    );
    final height = bundle.drafts.firstWhere(
      (d) => d.structured.type == 'growth_height',
    );

    expect(weight.title, s.growthTabWeight);
    expect(height.title, s.growthTabHeight);
    expect(weight.displayLine, contains('100'));
    expect(height.displayLine, contains('2'));
    expect(weight.growthPreview, isNotNull);
    expect(height.growthPreview, isNotNull);
    expect(weight.growthPreview!.newValue, closeTo(5.1, 0.01));
    expect(height.growthPreview!.newValue, closeTo(62, 0.01));
  });
}
