import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/models/ai/ai_nanny_parsed_message.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_local_message_parser.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_clarification.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_mapper.dart';
import 'package:facebaby_flutter/services/ai/detected_record_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const s = S(AppLang.pt);

  test('agende consulta para sexta fica completo', () {
    const msg = 'agende uma consulta para sexta';
    final parse = AiNannyLocalMessageParser.parse(msg);
    expect(parse.hasRecords, isTrue);
    final rec = parse.records.firstWhere((r) => r.type == 'appointment');
    final enforced = AiNannyStructuredClarification.enforce(rec, msg);
    expect(enforced.missingFields, isEmpty);
    expect(enforced.fields['reasonOrSpecialty'], 'Consulta');
    expect(enforced.fields['date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));

    final detected = DetectedRecordBuilder.fromStructured(enforced, s);
    expect(detected.missingLines, isEmpty);
    expect(detected.canSave, isTrue);

    final interp = AiNannyStructuredMapper.toInterpretation(enforced);
    expect(interp?.type, 'consultation');
    expect(interp?.consultation?.title, 'Consulta');
  });

  test('bundle de consulta para sexta é complete', () {
    const msg = 'agende uma consulta para sexta';
    final parse = AiNannyLocalMessageParser.parse(msg);
    final bundle = AiNannyStructuredMapper.prepareBundle(
      bundle: AiNannyStructuredMapper.buildBundle(
        parse: parse,
        userMessage: msg,
        strings: s,
      ),
      strings: s,
    );
    expect(bundle.incompleteCount, 0);
    expect(bundle.drafts.first.status, AiNannyRecordDraftStatus.complete);
  });
}
