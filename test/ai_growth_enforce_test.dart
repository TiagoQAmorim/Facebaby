import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/models/ai/ai_nanny_parsed_message.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_local_message_parser.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_clarification.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_mapper.dart';
import 'package:facebaby_flutter/services/ai/detected_record_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const s = S(AppLang.pt);

  test('peso total fica completo após enforce e mapeia para weight', () {
    const msg = 'Ela pesou 4,2 kg hoje';
    final parse = AiNannyLocalMessageParser.parse(msg);
    expect(parse.hasRecords, isTrue);
    final rec = parse.records.firstWhere((r) => r.type == 'growth_weight');
    final enforced = AiNannyStructuredClarification.enforce(rec, msg);
    expect(enforced.missingFields, isEmpty);
    expect(enforced.fields['mode'], 'total');
    expect((enforced.fields['value'] as num).toDouble(), closeTo(4.2, 0.01));

    final bundle = AiNannyStructuredMapper.prepareBundle(
      bundle: AiNannyStructuredMapper.buildBundle(
        parse: parse,
        userMessage: msg,
        strings: s,
      ),
      strings: s,
      lastWeightKg: 4.0,
    );
    expect(bundle.incompleteCount, 0);
    final draft = bundle.drafts.first;
    expect(draft.status, AiNannyRecordDraftStatus.complete);

    final interp = AiNannyStructuredMapper.toInterpretation(enforced);
    expect(interp?.type, 'weight');
    expect(interp?.weight?.weightKg, closeTo(4.2, 0.01));
  });

  test('delta de peso gera needsConfirm com preview sobre baseline atual', () {
    const msg = 'Ganhou 300 gramas';
    final parse = AiNannyLocalMessageParser.parse(msg);
    final bundle = AiNannyStructuredMapper.prepareBundle(
      bundle: AiNannyStructuredMapper.buildBundle(
        parse: parse,
        userMessage: msg,
        strings: s,
      ),
      strings: s,
      lastWeightKg: 5.0,
    );
    final draft = bundle.drafts.first;
    expect(draft.status, AiNannyRecordDraftStatus.needsConfirm);
    expect(draft.growthPreview, isNotNull);
    expect(draft.growthPreview!.previousValue, closeTo(5.0, 0.01));
    expect(draft.growthPreview!.newValue, closeTo(5.3, 0.01));
  });

  test('engordou 200g parseia delta de peso', () {
    const msg = 'a bebe engordou 200g';
    final parse = AiNannyLocalMessageParser.parse(msg);
    expect(parse.hasRecords, isTrue);
    final rec = parse.records.firstWhere((r) => r.type == 'growth_weight');
    expect(rec.fields['value'], 200);
    expect(rec.fields['mode'], 'delta');
    final enforced = AiNannyStructuredClarification.enforce(rec, msg);
    expect(enforced.missingFields, isEmpty);
  });

  test('cresceu X cm não mostra Tipo faltando', () {
    const msg = 'a bebe cresceu 5 cm';
    final parse = AiNannyLocalMessageParser.parse(msg);
    expect(parse.hasRecords, isTrue);
    final rec = parse.records.firstWhere((r) => r.type == 'growth_height');
    final enforced = AiNannyStructuredClarification.enforce(rec, msg);
    expect(enforced.missingFields, isEmpty);
    expect(enforced.fields['value'], 5);

    final detected = DetectedRecordBuilder.fromStructured(enforced, s);
    expect(
      detected.missingLines.any((l) => l.contains(s.aiRecordFieldType)),
      isFalse,
    );
    expect(
      detected.understoodLines.any((l) => l.contains('5')),
      isTrue,
    );
  });

  test('remove pee/poop espúrios em registro de altura', () {
    const msg = 'a bebe cresceu 5 cm';
    const rec = AiNannyStructuredRecord(
      type: 'growth_height',
      missingFields: ['pee', 'poop', 'type'],
      fields: {'value': 5, 'mode': 'delta', 'unit': 'cm'},
    );
    final enforced = AiNannyStructuredClarification.enforce(rec, msg);
    expect(enforced.missingFields, isEmpty);
    final detected = DetectedRecordBuilder.fromStructured(enforced, s);
    expect(detected.missingLines, isEmpty);
    expect(detected.canSave, isTrue);
  });

  test('alias height vira growth_height', () {
    const msg = 'cresceu 3 cm';
    const rec = AiNannyStructuredRecord(
      type: 'height',
      fields: {'value': 3, 'mode': 'delta', 'unit': 'cm'},
    );
    final enforced = AiNannyStructuredClarification.enforce(rec, msg);
    expect(enforced.type, 'growth_height');
    expect(enforced.missingFields, isEmpty);
  });
}
