import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/models/ai/ai_nanny_parsed_message.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_local_message_parser.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_parse_result_normalizer.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_clarification.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final s = const S(AppLang.pt);

  test('breastfeeding without side marks missing and asks options', () {
    const text = 'O bebê mamou no peito.';
    final parse = AiNannyParseResultNormalizer.normalize(
      AiNannyLocalMessageParser.parse(text),
      text,
    );
    expect(parse.records, hasLength(1));
    expect(parse.records.first.missingFields, contains('breastSide'));
    expect(parse.records.first.missingFields, contains('durationMinutes'));

    final bundle = AiNannyStructuredMapper.buildBundle(
      parse: parse,
      userMessage: text,
      strings: s,
    );
    final draft = bundle.drafts.single;
    expect(draft.title, contains('Amamentação'));
    expect(draft.detailLines, isNotEmpty);
    expect(draft.followUpQuestion, contains('Esquerdo'));
    final reply = AiNannyStructuredClarification.buildActionFirstReply(bundle, s);
    expect(reply, contains('Entendi'));
    expect(reply, contains('lado'));
    expect(reply, isNot(contains('responda no chat')));
  });

  test('diaper without type asks pee/poop options', () {
    const text = 'Troquei a fralda.';
    final parse = AiNannyParseResultNormalizer.normalize(
      AiNannyLocalMessageParser.parse(text),
      text,
    );
    expect(parse.records.first.type, 'diaper');
    expect(parse.records.first.missingFields, isNotEmpty);

    final bundle = AiNannyStructuredMapper.buildBundle(
      parse: parse,
      userMessage: text,
      strings: s,
    );
    expect(bundle.drafts.single.followUpQuestion, contains('Xixi'));
  });

  test('multi-record creates two draft cards', () {
    const text = 'O bebê mamou e troquei a fralda com cocô.';
    final parse = AiNannyParseResultNormalizer.normalize(
      AiNannyLocalMessageParser.parse(text),
      text,
    );
    expect(parse.records.length, greaterThanOrEqualTo(2));
    final bundle = AiNannyStructuredMapper.buildBundle(
      parse: parse,
      userMessage: text,
      strings: s,
    );
    expect(bundle.drafts.length, greaterThanOrEqualTo(2));
    expect(bundle.drafts.every((d) => d.hasCardContent), isTrue);
  });

  test('enforce removes invented breast side not in transcript', () {
    const rec = AiNannyStructuredRecord(
      type: 'feeding',
      fields: {
        'feedingType': 'breastfeeding',
        'breastSide': 'left',
        'time': 'now',
      },
    );
    final enforced = AiNannyStructuredClarification.enforce(
      rec,
      'O bebê mamou.',
    );
    expect(enforced.missingFields, contains('breastSide'));
    expect(enforced.fields['breastSide'], isNull);
  });
}
