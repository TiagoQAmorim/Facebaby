import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/models/ai/ai_nanny_parsed_message.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_intent_lexicon.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_local_message_parser.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_parse_merge.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_mapper.dart';
import 'package:facebaby_flutter/services/ai/routine_record_interpreter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const strings = S(AppLang.pt);

  AiNannyStructuredRecord? findRecord(
    AiNannyParseResult r,
    String type,
  ) {
    for (final rec in r.records) {
      if (rec.type == type) return rec;
    }
    return null;
  }

  group('AiNannyLocalMessageParser', () {
    test('multi: fralda + mamada + temperatura', () {
      const msg =
          'Ela acabou de cagar, mijar, mamou no peito esquerdo por 10 minutos e está com 37,5.';
      final r = AiNannyLocalMessageParser.parse(msg);
      expect(r.hasRecords, isTrue);

      final diaper = findRecord(r, 'diaper')!;
      expect(diaper.fields['pee'], isTrue);
      expect(diaper.fields['poop'], isTrue);

      final feeding = findRecord(r, 'feeding')!;
      expect(feeding.fields['feedingType'], 'breastfeeding');
      expect(feeding.fields['breastSide'], 'left');
      expect(feeding.fields['durationMinutes'], 10);

      final symptom = findRecord(r, 'health_symptom')!;
      expect(symptom.fields['temperatureCelsius'], closeTo(37.5, 0.01));
      // symptoms list uses canonical English tokens
    });

    test('crescimento delta peso e altura', () {
      const msg = 'Ganhou 200 gramas e cresceu 2cm.';
      final r = AiNannyLocalMessageParser.parse(msg);
      final w = findRecord(r, 'growth_weight')!;
      expect(w.fields['mode'], 'delta');
      expect(w.fields['value'], 200);
      expect(w.fields['unit'], 'g');

      final h = findRecord(r, 'growth_height')!;
      expect(h.fields['mode'], 'delta');
      expect(h.fields['value'], 2);
    });

    test('crescimento total peso e altura', () {
      const msg = 'Ela está com 5kg e 58cm.';
      final r = AiNannyLocalMessageParser.parse(msg);
      final w = findRecord(r, 'growth_weight')!;
      expect(w.fields['mode'], 'total');
      expect(w.fields['value'], closeTo(5, 0.01));

      final h = findRecord(r, 'growth_height')!;
      expect(h.fields['mode'], 'total');
      expect(h.fields['value'], closeTo(58, 0.01));
    });

    test('consulta agendada', () {
      const msg = 'Agendar consulta com pediatra amanhã às 15h.';
      final r = AiNannyLocalMessageParser.parse(msg);
      final a = findRecord(r, 'appointment')!;
      expect(a.fields['reasonOrSpecialty'], 'pediatra');
      expect(a.fields['date'], 'tomorrow');
      expect(a.fields['time'], '15:00');
    });

    test('vacina tomada', () {
      const msg = 'Tomou vacina BCG hoje.';
      final r = AiNannyLocalMessageParser.parse(msg);
      final v = findRecord(r, 'vaccine')!;
      expect(v.fields['status'], 'taken');
      expect('${v.fields['vaccineName']}'.toUpperCase(), contains('BCG'));
      expect(v.fields['date'], 'today');
    });

    test('vacina agendada', () {
      const msg = 'Agendar vacina pentavalente segunda às 10h.';
      final r = AiNannyLocalMessageParser.parse(msg);
      final v = findRecord(r, 'vaccine')!;
      expect(v.fields['status'], 'scheduled');
      expect('${v.fields['vaccineName']}', contains('pentavalente'));
      expect(v.fields['date'], 'next_monday');
      expect(v.fields['time'], '10:00');
    });

    test('não fez xixi hoje — conversa, sem registro de fralda', () {
      const msg = 'A bebê não fez xixi hoje';
      expect(AiNannyIntentLexicon.isDiaperAbsenceObservation(msg), isTrue);
      final r = AiNannyLocalMessageParser.parse(msg);
      expect(r.hasRecords, isFalse);
      expect(r.classification, 'chat_only');
      expect(findRecord(r, 'diaper'), isNull);
    });

    test('fez xixi — registra fralda com xixi', () {
      const msg = 'A bebê fez xixi agora';
      expect(AiNannyIntentLexicon.isDiaperAbsenceObservation(msg), isFalse);
      final r = AiNannyLocalMessageParser.parse(msg);
      final diaper = findRecord(r, 'diaper');
      expect(diaper, isNotNull);
      expect(diaper!.fields['pee'], isTrue);
      expect(diaper.fields['poop'], isFalse);
    });

    test('merge remove fralda espúria em negação', () {
      const msg = 'A bebê não fez xixi hoje';
      final cloud = AiNannyParseResult(
        classification: 'create_records',
        records: [
          AiNannyStructuredRecord(
            type: 'diaper',
            fields: {'pee': true, 'poop': false, 'time': 'now'},
          ),
        ],
      );
      final local = AiNannyLocalMessageParser.parse(msg);
      final merged = AiNannyParseMerge.merge(cloud, local, msg);
      expect(merged.hasRecords, isFalse);
      expect(merged.classification, 'chat_only');
    });

    test('não mamou — conversa, sem registro de mamada', () {
      const msg = 'A bebê não mamou hoje';
      final r = AiNannyLocalMessageParser.parse(msg);
      expect(r.hasRecords, isFalse);
      expect(findRecord(r, 'feeding'), isNull);
    });

    test('não aumentou o peso — conversa, sem registro de peso', () {
      const msg = 'Ela não aumentou o peso esta semana';
      final r = AiNannyLocalMessageParser.parse(msg);
      expect(r.hasRecords, isFalse);
      expect(findRecord(r, 'growth_weight'), isNull);
    });

    test('não cresceu — conversa, sem registro de altura', () {
      const msg = 'O bebê não cresceu este mês';
      final r = AiNannyLocalMessageParser.parse(msg);
      expect(r.hasRecords, isFalse);
      expect(findRecord(r, 'growth_height'), isNull);
    });

    test('perdeu 200 gramas — delta negativo de peso', () {
      const msg = 'A bebê perdeu 200 gramas';
      final r = AiNannyLocalMessageParser.parse(msg);
      final w = findRecord(r, 'growth_weight');
      expect(w, isNotNull);
      expect(w!.fields['value'], -200);
      expect(w.fields['mode'], 'delta');
      expect(w.fields['unit'], 'g');
    });

    test('emagreceu 150 gramas — delta negativo', () {
      final r = AiNannyLocalMessageParser.parse('Emagreceu 150 gramas');
      expect(findRecord(r, 'growth_weight')!.fields['value'], -150);
    });
  });

  group('rotina e confirmação', () {
    test('"e ganhou 150g" dispara extração estruturada', () {
      expect(
        RoutineRecordInterpreter.transcriptHasRoutineCue('e ganhou 150g'),
        isTrue,
      );
      final r = AiNannyLocalMessageParser.parse('e ganhou 150g');
      expect(r.hasRecords, isTrue);
      expect(findRecord(r, 'growth_weight')!.fields['value'], 150);
    });

    test('"registra isso" pede confirmação de gravação', () {
      expect(AiNannyIntentLexicon.wantsConfirmSave('registra isso'), isTrue);
      expect(AiNannyIntentLexicon.wantsConfirmSave('oi tudo bem'), isFalse);
    });

    test('acordou + cresceu 1 cm → sono e altura', () {
      const msg =
          'a bebe acordou feliz agora, parece estar com fome, ah e cresceu 1 cm';
      final r = AiNannyLocalMessageParser.parse(msg);
      expect(r.hasRecords, isTrue);
      expect(r.records.length, greaterThanOrEqualTo(2));
      expect(findRecord(r, 'sleep'), isNotNull);
      expect(findRecord(r, 'growth_height'), isNotNull);
      expect(findRecord(r, 'growth_height')!.fields['value'], closeTo(1, 0.01));
    });
  });

  group('AiNannyStructuredMapper', () {
    test('bundle marca delta de peso como needsConfirm', () {
      final parse = AiNannyLocalMessageParser.parse('Ganhou 200 gramas.');
      final bundle = AiNannyStructuredMapper.buildBundle(
        parse: parse,
        userMessage: 'Ganhou 200 gramas.',
        strings: strings,
        lastWeightKg: 5.0,
      );
      expect(bundle.drafts.single.status, AiNannyRecordDraftStatus.needsConfirm);
      expect(bundle.drafts.single.growthPreview?.newValue, closeTo(5.2, 0.001));
    });
  });
}
