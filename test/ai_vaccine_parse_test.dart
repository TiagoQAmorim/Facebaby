import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/utils/ai_nanny_parse_normalize.dart';
import 'package:facebaby_flutter/models/ai/ai_nanny_parsed_message.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_local_message_parser.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_clarification.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_mapper.dart';
import 'package:facebaby_flutter/services/ai/detected_record_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const s = S(AppLang.pt);

  test('tomou vacina B1 hoje com próxima em 30 dias grava nextDueAt', () {
    const msg =
        'a Maitê tomou a vacina B1 hoje, próxima dose daqui a 30 dias';
    final parse = AiNannyLocalMessageParser.parse(msg);
    expect(parse.hasRecords, isTrue);
    final rec = parse.records.firstWhere((r) => r.type == 'vaccine');
    expect(rec.fields['vaccineName'], 'B1');
    expect(rec.fields['nextDueInDays'], 30);
    expect(rec.fields['nextDueDate'], isNotNull);

    final enforced = AiNannyStructuredClarification.enforce(rec, msg);
    expect(enforced.missingFields, isEmpty);
    expect(enforced.fields['status'], 'taken');
    expect(enforced.fields['vaccineName'], 'B1');
    expect(enforced.fields['nextDueInDays'], 30);

    final detected = DetectedRecordBuilder.fromStructured(enforced, s);
    expect(detected.missingLines, isEmpty);
    expect(detected.canSave, isTrue);

    final interp = AiNannyStructuredMapper.toInterpretation(enforced);
    expect(interp?.type, 'vaccine');
    expect(interp?.vaccine?.name, 'B1');
    expect(interp?.vaccine?.appliedAt, isNotNull);
    expect(interp?.vaccine?.nextDueAt, isNotNull);
    final due = interp!.vaccine!.nextDueAt!;
    final expected = DateTime.now().add(const Duration(days: 30));
    expect(due.year, expected.year);
    expect(due.month, expected.month);
    expect(due.day, expected.day);
  });

  test('frase da screenshot: B1 tomada e próxima só daqui a 60 dias', () {
    const msg =
        'Ela acabou de tomar uma vacina, a B1, vacina B1, e agora a próxima é só daqui a 60 dias.';
    expect(AiNannyParseNormalize.parseVaccineNextDueInDays(msg), 60);
    final parse = AiNannyLocalMessageParser.parse(msg);
    final rec = parse.records.firstWhere((r) => r.type == 'vaccine');
    final enforced = AiNannyStructuredClarification.enforce(rec, msg);
    final interp = AiNannyStructuredMapper.toInterpretation(enforced);
    expect(interp?.vaccine?.nextDueAt, isNotNull);
    final due = interp!.vaccine!.nextDueAt!;
    final expected = DateTime.now().add(const Duration(days: 60));
    expect(due.day, expected.day);
    expect(due.month, expected.month);
  });

  test('criar registro vacina B1 para daqui 30 dias é complete', () {
    const msg = 'criar um registro de vacina B1 para daqui 30 dias';
    final parse = AiNannyLocalMessageParser.parse(msg);
    expect(parse.hasRecords, isTrue);
    final rec = parse.records.firstWhere((r) => r.type == 'vaccine');
    expect(rec.fields['vaccineName'], 'B1');
    expect(rec.fields['nextDueInDays'], 30);
    expect(rec.missingFields, isEmpty);

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

  test('registra vacina B5 para daqui 25 dias — agendada sem data aplicada', () {
    const msg = 'registra uma vacina b5 para daqui 25 dias';
    expect(AiNannyParseNormalize.parseVaccineNextDueInDays(msg), 25);
    final parse = AiNannyLocalMessageParser.parse(msg);
    final rec = parse.records.firstWhere((r) => r.type == 'vaccine');
    expect(rec.fields['vaccineName'], 'B5');
    final enforced = AiNannyStructuredClarification.enforce(rec, msg);
    expect(enforced.fields['status'], 'scheduled');
    expect(enforced.fields['nextDueInDays'], 25);
    expect(enforced.fields['date'], isNull);

    final interp = AiNannyStructuredMapper.toInterpretation(enforced);
    expect(interp?.vaccine?.appliedAt, isNull);
    expect(interp?.vaccine?.nextDueAt, isNotNull);
    final due = interp!.vaccine!.nextDueAt!;
    final expected = DateTime.now().add(const Duration(days: 25));
    expect(due.year, expected.year);
    expect(due.month, expected.month);
    expect(due.day, expected.day);
  });

  test('bundle vacina B1 é complete', () {
    const msg = 'tomou a vacina B1 hoje';
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
