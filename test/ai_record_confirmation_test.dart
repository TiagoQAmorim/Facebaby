import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/models/ai/voice_record_interpretation.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_record_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const s = S(AppLang.pt);

  test('consultation confirmation names specialty, not generic registro', () {
    const interp = VoiceRecordInterpretation(
      type: 'consultation',
      summary: 'Consulta pediatra',
      consultation: VoiceConsultationPayload(
        title: 'Pediatra',
        occurredAt: null,
      ),
    );
    final msg = AiNannyRecordActions.buildSuccessConfirmation(
      interpretation: interp,
      babyName: 'Sophie',
      strings: s,
      transcript:
          'a neném vai ter uma consulta no sábado às nove da manhã, pediatra.',
    );
    expect(msg, contains('consulta'));
    expect(msg, contains('Pediatra'));
    expect(msg, isNot(contains('registrei registro')));
    expect(msg, isNot(contains('registrei um registro')));
  });

  test('consultation without address asks for clinic address', () {
    const interp = VoiceRecordInterpretation(
      type: 'consultation',
      summary: 'Consulta',
      consultation: VoiceConsultationPayload(title: 'Pediatra'),
    );
    final msg = AiNannyRecordActions.buildSuccessConfirmation(
      interpretation: interp,
      babyName: 'Sophie',
      strings: s,
      transcript: 'consulta no sábado às 9h com pediatra',
    );
    expect(msg, contains(s.aiClarifyAppointmentAddress));
  });

  test('consultation with address in message does not ask again', () {
    const interp = VoiceRecordInterpretation(
      type: 'consultation',
      summary: 'Consulta',
      consultation: VoiceConsultationPayload(
        title: 'Pediatra',
        address: 'Rua das Flores, 100',
      ),
    );
    final msg = AiNannyRecordActions.buildSuccessConfirmation(
      interpretation: interp,
      babyName: 'Sophie',
      strings: s,
    );
    expect(msg, isNot(contains(s.aiClarifyAppointmentAddress)));
  });
}
