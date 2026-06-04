import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/models/ai/ai_nanny_parsed_message.dart';
import 'package:facebaby_flutter/services/ai/breastfeeding_both_helper.dart';
import 'package:facebaby_flutter/services/ai/detected_record_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const s = S(AppLang.pt);

  test('expandAtIndex divide em esquerdo+direito quando resolved é both', () {
    final before = AiNannyRecordDraft(
      structured: const AiNannyStructuredRecord(
        type: 'feeding',
        fields: {'feedingType': 'breastfeeding'},
        missingFields: ['breastSide', 'durationMinutes'],
      ),
      status: AiNannyRecordDraftStatus.incomplete,
      displayLine: 'Mamada',
      title: 'Mamada',
    );
    final resolved = const AiNannyStructuredRecord(
      type: 'feeding',
      fields: {
        'feedingType': 'breastfeeding',
        'breastSide': 'both',
      },
      missingFields: ['durationMinutes'],
    );

    final expanded = BreastfeedingBothHelper.expandAtIndex(
      [before],
      0,
      resolved: resolved,
      strings: s,
      sourceText: 'ambos',
    );

    expect(expanded.length, 2);
    expect(expanded[0].structured.fields['breastSide'], 'left');
    expect(expanded[1].structured.fields['breastSide'], 'right');
    expect(
      expanded[0].structured.missingFields,
      contains('durationMinutes'),
    );
    expect(
      expanded[1].structured.missingFields,
      contains('durationMinutes'),
    );

    final followUps =
        DetectedRecordBuilder.followUpsForBundle(expanded, s);
    expect(followUps.length, greaterThanOrEqualTo(2));
    expect(
      followUps.any((q) => q.field == 'durationMinutes' && q.recordIndex == 0),
      isTrue,
    );
    expect(
      followUps.any((q) => q.field == 'durationMinutes' && q.recordIndex == 1),
      isTrue,
    );
    expect(
      followUps.first.question,
      contains('esquerd'),
    );
  });
}
