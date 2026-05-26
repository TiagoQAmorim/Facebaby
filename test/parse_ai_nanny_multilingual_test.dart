import 'package:facebaby_flutter/models/ai/ai_nanny_parsed_message.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_local_message_parser.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_parse_result_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expectedBreastLeft10 = {
    'type': 'feeding',
    'feedingType': 'breastfeeding',
    'breastSide': 'left',
    'durationMinutes': 10,
  };

  final feedingPhrases = <String, String>{
    'pt_BR':
        'Ela mamou no peito esquerdo por 10 minutos.',
    'en_US':
        'She breastfed on the left side for 10 minutes.',
    'es_ES':
        'Tomó pecho del lado izquierdo por 10 minutos.',
    'it_IT':
        'Ha allattato dal lato sinistro per 10 minuti.',
    'fr_FR':
        'Elle a allaité du côté gauche pendant 10 minutes.',
    'de_DE':
        'Sie wurde 10 Minuten an der linken Brust gestillt.',
  };

  group('Multilingual feeding — mesmo JSON canónico', () {
    for (final entry in feedingPhrases.entries) {
      test('${entry.key}', () {
        final raw = AiNannyLocalMessageParser.parse(entry.value);
        final result = AiNannyParseResultNormalizer.normalize(
          raw,
          entry.value,
        );
        expect(result.hasRecords, isTrue, reason: entry.key);
        final feeding = result.records
            .firstWhere((r) => r.type == 'feeding')
            .toCanonicalMap();
        expect(feeding['type'], expectedBreastLeft10['type']);
        expect(feeding['feedingType'], expectedBreastLeft10['feedingType']);
        expect(feeding['breastSide'], expectedBreastLeft10['breastSide']);
        expect(feeding['durationMinutes'], expectedBreastLeft10['durationMinutes']);
      });
    }

    test('todas as línguas produzem estrutura equivalente', () {
      final canonical = <Map<String, dynamic>>[];
      for (final phrase in feedingPhrases.values) {
        final r = AiNannyParseResultNormalizer.normalize(
          AiNannyLocalMessageParser.parse(phrase),
          phrase,
        );
        canonical.add(
          r.records.firstWhere((e) => e.type == 'feeding').toCanonicalMap(),
        );
      }
      for (var i = 1; i < canonical.length; i++) {
        expect(canonical[i]['feedingType'], canonical[0]['feedingType']);
        expect(canonical[i]['breastSide'], canonical[0]['breastSide']);
        expect(canonical[i]['durationMinutes'], canonical[0]['durationMinutes']);
      }
    });
  });

  group('Multilingual temperature', () {
    final phrases = {
      'pt': 'Está com 37,5.',
      'en': 'Temperature is 37.5.',
      'es': 'Tiene 37,5 de fiebre.',
      'fr': 'Elle a 37,5 de fièvre.',
      'de': 'Temperatur 37,5.',
    };

    for (final e in phrases.entries) {
      test(e.key, () {
        final r = AiNannyParseResultNormalizer.normalize(
          AiNannyLocalMessageParser.parse(e.value),
          e.value,
        );
        final sym = r.records.firstWhere((x) => x.type == 'health_symptom');
        expect(sym.fields['temperatureCelsius'], closeTo(37.5, 0.01));
      });
    }
  });

  group('Multilingual diaper pee+poop', () {
    test('PT e EN equivalentes', () {
      final pt = AiNannyLocalMessageParser.parse(
        'Ela acabou de cagar e mijar.',
      );
      final en = AiNannyLocalMessageParser.parse(
        'She just pooped and peed.',
      );
      final ptD = pt.records.firstWhere((r) => r.type == 'diaper');
      final enD = en.records.firstWhere((r) => r.type == 'diaper');
      expect(ptD.fields['pee'], isTrue);
      expect(ptD.fields['poop'], isTrue);
      expect(enD.fields['pee'], isTrue);
      expect(enD.fields['poop'], isTrue);
    });
  });
}
