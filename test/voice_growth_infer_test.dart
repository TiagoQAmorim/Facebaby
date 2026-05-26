import 'package:flutter_test/flutter_test.dart';
import 'package:facebaby_flutter/models/ai/voice_record_interpretation.dart';
import 'package:facebaby_flutter/utils/voice_growth_infer.dart';
import 'package:facebaby_flutter/utils/voice_record_infer.dart';

void main() {
  test('infers height from cresceu X centimetros', () {
    final out = enhanceVoiceGrowthInterpretation(
      interpretation: const VoiceRecordInterpretation.unknown(),
      transcript: 'A neném cresceu 5 centímetros',
    );
    expect(out.type, 'height');
    expect(out.height?.heightDeltaCm, 5);
    expect(out.canRegister, isTrue);
  });

  test('infers absolute height in cm', () {
    final out = enhanceVoiceGrowthInterpretation(
      interpretation: const VoiceRecordInterpretation.unknown(),
      transcript: 'altura 62 centímetros',
    );
    expect(out.type, 'height');
    expect(out.height?.heightCm, 62);
  });

  test('replaces bad OpenAI summary for height', () {
    final out = enhanceVoiceRecordInterpretation(
      interpretation: const VoiceRecordInterpretation(
        type: 'height',
        summary: 'Registro não identificado.',
        height: VoiceHeightPayload(heightDeltaCm: 5),
      ),
      transcript: 'A neném cresceu 5 centímetros',
    );
    expect(out.canRegister, isTrue);
    expect(out.summary.toLowerCase(), isNot(contains('não identificado')));
    expect(out.summary, contains('5'));
  });

  test('infers weight in kg', () {
    final out = enhanceVoiceGrowthInterpretation(
      interpretation: const VoiceRecordInterpretation.unknown(),
      transcript: 'Maitê pesou 3,5 kg',
    );
    expect(out.type, 'weight');
    expect(out.weight?.weightKg, closeTo(3.5, 0.01));
  });
}
