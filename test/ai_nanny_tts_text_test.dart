import 'package:facebaby_flutter/utils/ai_nanny_tts_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('prepareAiNannyTtsText', () {
    test('remove emojis e espaços extras', () {
      const raw = '🤖  Olá!  Tudo bem?  👶';
      expect(prepareAiNannyTtsText(raw), 'Olá! Tudo bem?');
    });

    test('limita texto longo em fronteira de frase', () {
      final long = '${'A' * 400}. ${'B' * 200}.';
      final out = prepareAiNannyTtsText(long, maxLen: 420);
      expect(out.length, lessThanOrEqualTo(425));
      expect(out.endsWith('…'), isTrue);
    });
  });
}
