import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/models/ai/ai_nanny_parsed_message.dart';
import 'package:facebaby_flutter/models/ai/ai_nanny_system_context.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_local_message_parser.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_orchestrator.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_parse_result_normalizer.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_structured_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

AiNannyRecordsBundle _bundleFor(
  String text,
  AiNannySystemContext ctx,
  S s,
) {
  final parse = AiNannyParseResultNormalizer.normalize(
    AiNannyLocalMessageParser.parse(text),
    text,
  );
  final enriched = AiNannyOrchestrator.enrichParse(
    parse: parse,
    context: ctx,
    sourceText: text,
  );
  return AiNannyStructuredMapper.prepareBundle(
    bundle: AiNannyStructuredMapper.buildBundle(
      parse: enriched,
      userMessage: text,
      strings: s,
    ),
    strings: s,
    systemContext: ctx,
  );
}

void main() {
  final s = const S(AppLang.pt);

  group('sleep timer', () {
    test('Test 1: active sleep timer — no duration question on wake', () {
      const text = 'A bebê acordou agora.';
      final started = DateTime.now().subtract(const Duration(minutes: 65));
      final ctx = AiNannySystemContext(
        babyId: 1,
        activeSleep: ActiveSleepSessionInfo(
          babyId: 1,
          startedAt: started,
          durationMinutes: 65,
          durationSec: 65 * 60,
        ),
      );

      final bundle = _bundleFor(text, ctx, s);
      final sleep = bundle.drafts.firstWhere((d) => d.structured.type == 'sleep');

      expect(sleep.structured.fields['fromActiveTimer'], true);
      expect(sleep.structured.missingFields, isNot(contains('durationMinutes')));
      expect(
        bundle.followUpQuestions.where((q) => q.field == 'durationMinutes'),
        isEmpty,
      );

      final reply = AiNannyOrchestrator.buildSmartReply(bundle, ctx, s)!;
      expect(reply, isNot(contains('Quanto tempo ela dormiu')));
      expect(reply, contains('1h05'));
    });

    test('Test 2: no sleep timer — asks duration on wake', () {
      const text = 'A bebê acordou.';
      const ctx = AiNannySystemContext(babyId: 1);

      final bundle = _bundleFor(text, ctx, s);
      final sleep = bundle.drafts.firstWhere((d) => d.structured.type == 'sleep');

      expect(sleep.structured.fields['fromActiveTimer'], isNot(true));
      expect(sleep.structured.missingFields, contains('durationMinutes'));
      expect(
        bundle.followUpQuestions.any((q) => q.field == 'durationMinutes'),
        isTrue,
      );
    });
  });

  group('breastfeeding timer', () {
    test('Test 3: active left breast timer — no duration question', () {
      const text = 'Ela mamou agora.';
      final started = DateTime.now().subtract(const Duration(minutes: 14));
      final ctx = AiNannySystemContext(
        babyId: 1,
        activeBreastfeeding: ActiveBreastfeedingSessionInfo(
          babyId: 1,
          side: 'E',
          startedAt: started,
          durationMinutes: 14,
        ),
      );

      final bundle = _bundleFor(text, ctx, s);
      final feeding =
          bundle.drafts.firstWhere((d) => d.structured.type == 'feeding');

      expect(feeding.structured.fields['fromActiveTimer'], true);
      expect(feeding.structured.fields['breastSide'], 'left');
      expect(feeding.structured.missingFields, isNot(contains('durationMinutes')));
      expect(
        bundle.followUpQuestions.where((q) => q.field == 'durationMinutes'),
        isEmpty,
      );

      final reply = AiNannyOrchestrator.buildSmartReply(bundle, ctx, s)!;
      expect(reply, isNot(contains('Quanto tempo ela mamou')));
      expect(reply.toLowerCase(), contains('esquerdo'));
      expect(reply, contains('14'));
    });

    test('Test 4: no feeding session — asks duration or side', () {
      const text = 'Ela mamou.';
      const ctx = AiNannySystemContext(babyId: 1);

      final bundle = _bundleFor(text, ctx, s);
      final feeding =
          bundle.drafts.firstWhere((d) => d.structured.type == 'feeding');

      expect(feeding.structured.fields['fromActiveTimer'], isNot(true));
      expect(
        feeding.structured.missingFields.contains('durationMinutes') ||
            feeding.structured.missingFields.contains('breastSide'),
        isTrue,
      );
      expect(bundle.followUpQuestions, isNotEmpty);
    });
  });
}
