import 'package:flutter_test/flutter_test.dart';
import 'package:facebaby_flutter/models/ai/voice_record_interpretation.dart';
import 'package:facebaby_flutter/utils/voice_sleep_infer.dart';

void main() {
  test('unknown transcript colocou pra dormir becomes sleep start', () {
    final out = enhanceVoiceSleepInterpretation(
      interpretation: const VoiceRecordInterpretation.unknown(),
      transcript: 'Coloquei a neném pra dormir agora',
    );
    expect(out.type, 'sleep');
    expect(out.canRegister, isTrue);
    expect(out.sleep?.action, 'start');
  });

  test('unknown dormiu 1 hora becomes sleep complete with duration', () {
    final out = enhanceVoiceSleepInterpretation(
      interpretation: const VoiceRecordInterpretation.unknown(),
      transcript: 'A Maitê dormiu 1 hora',
    );
    expect(out.type, 'sleep');
    expect(out.sleep?.action, 'complete');
    expect(out.sleep?.durationMinutes, 60);
  });

  test('acordou becomes sleep end', () {
    final out = enhanceVoiceSleepInterpretation(
      interpretation: const VoiceRecordInterpretation.unknown(),
      transcript: 'Ela acordou agora',
    );
    expect(out.type, 'sleep');
    expect(out.sleep?.action, 'end');
  });
}
