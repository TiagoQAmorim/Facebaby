import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/models/ai/ai_nanny_parsed_message.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_local_message_parser.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_parse_result_normalizer.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_mapper.dart';
import 'package:facebaby_flutter/services/ai/breastfeeding_both_helper.dart';
import 'package:facebaby_flutter/services/ai/detected_record_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final s = const S(AppLang.pt);

  AiNannyRecordsBundle _bundleAfterBothChoice(String userText) {
    final parse = AiNannyParseResultNormalizer.normalize(
      AiNannyLocalMessageParser.parse(userText),
      userText,
    );
    final feeding = parse.records.firstWhere((r) => r.type == 'feeding');
    final withBoth = DetectedRecordBuilder.applyAnswer(
      rec: feeding,
      field: 'breastSide',
      value: s.aiRecordSideBoth,
      sourceText: userText,
    );
    final drafts = [
      AiNannyStructuredMapper.draftFromRecord(
        withBoth,
        strings: s,
        sourceText: '$userText ${s.aiRecordSideBoth}',
      ),
    ];
    final expanded = BreastfeedingBothHelper.expandDrafts(
      drafts,
      strings: s,
      sourceText: userText,
    );
    return AiNannyRecordsBundle(
      drafts: expanded,
      userMessage: userText,
      followUpQuestions: DetectedRecordBuilder.followUpsForBundle(expanded, s),
    );
  }

  test('Test 1: both choice splits into left and right — no single both record', () {
    const text = 'Ela mamou agora.';
    final bundle = _bundleAfterBothChoice(text);

    expect(bundle.drafts.length, 2);
    expect(
      bundle.drafts.any((d) => d.structured.fields['breastSide'] == 'both'),
      isFalse,
    );
    expect(
      bundle.drafts.map((d) => d.structured.fields['breastSide']).toList(),
      containsAll(['left', 'right']),
    );
    expect(bundle.followUpQuestions, isNotEmpty);
    expect(
      bundle.followUpQuestions.first.question,
      contains('esquerdo'),
    );
  });

  test('Test 2: "10 minutos cada" → left 10, right 10', () {
    const text = 'Ela mamou.';
    var bundle = _bundleAfterBothChoice(text);
    final dual = BreastfeedingBothHelper.tryApplyDualDurations(
      drafts: bundle.drafts,
      sourceText: '10 minutos cada',
      strings: s,
    );
    expect(dual, isNotNull);
    final left = dual!.firstWhere((d) => d.structured.fields['breastSide'] == 'left');
    final right = dual.firstWhere((d) => d.structured.fields['breastSide'] == 'right');
    expect(left.structured.fields['durationMinutes'], 10);
    expect(right.structured.fields['durationMinutes'], 10);
    expect(left.structured.missingFields, isEmpty);
    expect(right.structured.missingFields, isEmpty);
  });

  test('Test 3: "10 no esquerdo e 15 no direito" → left 10, right 15', () {
    const text = 'Ela mamou.';
    final bundle = _bundleAfterBothChoice(text);
    final dual = BreastfeedingBothHelper.tryApplyDualDurations(
      drafts: bundle.drafts,
      sourceText: '10 no esquerdo e 15 no direito',
      strings: s,
    );
    expect(dual, isNotNull);
    final left = dual!.firstWhere((d) => d.structured.fields['breastSide'] == 'left');
    final right = dual.firstWhere((d) => d.structured.fields['breastSide'] == 'right');
    expect(left.structured.fields['durationMinutes'], 10);
    expect(right.structured.fields['durationMinutes'], 15);
  });

  test('Test 4: partial bundle keeps only incomplete feeding drafts', () {
    const text = 'troquei fralda, ela mamou e dormiu';
    final parse = AiNannyParseResultNormalizer.normalize(
      AiNannyLocalMessageParser.parse(text),
      text,
    );
    final fullBundle = AiNannyStructuredMapper.prepareBundle(
      bundle: AiNannyStructuredMapper.buildBundle(
        parse: parse,
        userMessage: text,
        strings: s,
      ),
      strings: s,
    );

    final completeTypes = {'diaper', 'sleep'};
    final remaining = fullBundle.drafts
        .where((d) => !completeTypes.contains(d.structured.type))
        .toList();

    expect(remaining.length, lessThan(fullBundle.drafts.length));
    expect(remaining.every((d) => d.structured.type == 'feeding'), isTrue);
    expect(
      remaining.any((d) => completeTypes.contains(d.structured.type)),
      isFalse,
    );
  });

  test('parseDualDurations handles "10 e 15"', () {
    final d = BreastfeedingBothHelper.parseDualDurations('10 e 15');
    expect(d?.left, 10);
    expect(d?.right, 15);
  });

  test('Test 5: all complete bundle has no follow-ups', () {
    const text = 'Ela mamou.';
    var bundle = _bundleAfterBothChoice(text);
    final dual = BreastfeedingBothHelper.tryApplyDualDurations(
      drafts: bundle.drafts,
      sourceText: '10 minutos cada',
      strings: s,
    )!;
    bundle = AiNannyStructuredMapper.prepareBundle(
      bundle: AiNannyRecordsBundle(
        drafts: dual,
        userMessage: text,
      ),
      strings: s,
    );
    expect(bundle.allRequiredFilled, isTrue);
    expect(bundle.followUpQuestions, isEmpty);
  });
}
