import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/models/ai/ai_nanny_parsed_message.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_record_actions.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_mapper.dart';
import 'package:facebaby_flutter/services/ai/detected_record_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final s = const S(AppLang.pt);

  group('peito esquerdo + 15 minutos', () {
    test('mapper produz feeding peito E com duração', () {
      var rec = const AiNannyStructuredRecord(
        type: 'feeding',
        fields: {'feedingType': 'breastfeeding', 'breastSide': 'left'},
        missingFields: ['durationMinutes'],
      );
      rec = DetectedRecordBuilder.applyAnswer(
        rec: rec,
        field: 'durationMinutes',
        value: '15',
        sourceText: 'mamou no peito esquerdo 15',
      );
      expect(rec.fields['breastSide'], 'left');
      expect(rec.fields['feedingType'], 'breastfeeding');
      expect(rec.fields['durationMinutes'], 15);
      expect(rec.missingFields, isEmpty);

      final interp = AiNannyStructuredMapper.toInterpretation(rec);
      expect(interp, isNotNull);
      expect(interp!.type, 'feeding');
      expect(interp.feeding?.subtype, 'peito');
      expect(interp.feeding?.side, 'E');
      expect(interp.feeding?.note, contains('15'));
    });

    test('confirmação de sucesso só com peito e minutos', () {
      final rec = AiNannyStructuredRecord(
        type: 'feeding',
        fields: {
          'feedingType': 'breastfeeding',
          'breastSide': 'left',
          'durationMinutes': 15,
        },
        missingFields: const [],
      );
      final interp = AiNannyStructuredMapper.toInterpretation(rec)!;
      final msg = AiNannyRecordActions.buildSuccessConfirmation(
        interpretation: interp,
        babyName: 'Maitê',
        strings: s,
      );
      expect(msg, s.aiBreastfeedingSavedSuccess(s.aiRecordSideLeft, 15));
      expect(msg, isNot(contains('Pronto, registrei')));
    });

    test('resolveChatAnswer bloqueia registrei sem save real', () {
      const ai = 'Pronto, registrei a mamada no peito esquerdo.';
      final out = AiNannyRecordActions.resolveChatAnswer(
        aiAnswer: ai,
        saved: false,
        needsClarification: true,
        error: null,
        confirmation: null,
        clarificationPrompt: 'Quantos minutos?',
        strings: s,
      );
      expect(out.toLowerCase(), isNot(contains('registrei')));
      expect(out, contains('Quantos minutos'));
    });
  });
}
