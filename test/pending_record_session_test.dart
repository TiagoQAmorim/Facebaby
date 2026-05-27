import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_local_message_parser.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_parse_result_normalizer.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_clarification.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_mapper.dart';
import 'package:facebaby_flutter/services/ai/detected_record_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final s = const S(AppLang.pt);

  test('wake diaper breast message never uses generic clarification', () {
    const text = 'A neném acordou, troquei a fralda e dei mamar';
    final parse = AiNannyParseResultNormalizer.normalize(
      AiNannyLocalMessageParser.parse(text),
      text,
    );
    expect(parse.records.length, greaterThanOrEqualTo(2));

    final bundle = AiNannyStructuredMapper.prepareBundle(
      bundle: AiNannyStructuredMapper.buildBundle(
        parse: parse,
        userMessage: text,
        strings: s,
      ),
      strings: s,
    );
    expect(bundle.followUpQuestions, isNotEmpty);

    final reply = AiNannyStructuredClarification.buildActionFirstReply(bundle, s);
    expect(reply, contains('Ainda tenho'));
    expect(reply, contains('xixi'));
    expect(reply, isNot(contains('Antes de continuar')));
    expect(reply, isNot(contains('Preciso de um detalhe')));
  });

  test('triple routine message asks explicit diaper question first', () {
    const text = 'troquei a fralda da nenem, dei mamar e agora ja dormiu';
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
    expect(bundle.followUpQuestions, isNotEmpty);

    final reply = AiNannyStructuredClarification.buildActionFirstReply(bundle, s);
    expect(reply, contains('Ainda tenho'));
    expect(reply, contains('Fralda'));
    expect(reply, contains('xixi'));
    expect(reply, isNot(contains('Antes de continuar')));
    expect(reply, isNot(contains('responda no chat')));
  });

  test('follow-up index stays at first question after answer', () {
    const text = 'troquei a fralda da nenem, dei mamar e agora ja dormiu';
    final parse = AiNannyParseResultNormalizer.normalize(
      AiNannyLocalMessageParser.parse(text),
      text,
    );
    final bundle = AiNannyStructuredMapper.buildBundle(
      parse: parse,
      userMessage: text,
      strings: s,
    );
    final first = bundle.followUpQuestions.first;
    final draft = bundle.drafts[first.recordIndex].structured;
    final updated = DetectedRecordBuilder.applyAnswer(
      rec: draft,
      field: first.field,
      value: 'xixi',
      sourceText: text,
    );
    final drafts = List.of(bundle.drafts);
    drafts[first.recordIndex] = AiNannyStructuredMapper.draftFromRecord(
      updated,
      strings: s,
      sourceText: text,
    );
    final nextFollowUps = DetectedRecordBuilder.followUpsForBundle(drafts, s);
    expect(nextFollowUps, isNotEmpty);
    expect(
      nextFollowUps.first.question.toLowerCase(),
      isNot(contains('xixi')),
    );
  });
}
