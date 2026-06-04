import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/services/ai/ai_emotional_moment_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const s = S(AppLang.pt);

  test('boas-vindas explicam registros, dúvidas e desabafo', () {
    final msg = s.aiNannyWelcomeMessage;
    expect(msg.split('\n').length, lessThanOrEqualTo(6));
    expect(msg.length, lessThan(320));
    expect(msg, contains('IA Babá'));
    expect(msg, contains('registrar'));
    expect(msg, contains('dúvidas'));
    expect(msg, contains('conselheira'));
    expect(msg, contains('desabafar'));
    expect(msg, isNot(contains('alarmismo')));
  });

  test('dica de 2 meses alinhada ao exemplo do produto', () {
    expect(s.aiEmotionalDev2Months, contains('descobrindo'));
  });

  test('texto de mesversário contém nome e meses', () {
    final text = s.aiEmotionalMonthiversary(
      'Maitê',
      2,
      s.aiEmotionalDev2Months,
    );
    expect(text, contains('Maitê'));
    expect(text, contains('2'));
    expect(text, contains('meses'));
    expect(text, startsWith('🤖'));
  });

  test('TBT usa rótulo temporal', () {
    final text = s.aiEmotionalTbtPhoto('Maitê', s.aiEmotionalTbtMonth);
    expect(text, contains('Maitê'));
    expect(text, contains('mês'));
  });

  test('conquista alimentação menciona dias', () {
    final text = s.aiEmotionalAchieveFeedingStreak('Maitê', 7);
    expect(text, contains('7'));
    expect(text, contains('alimentação'));
  });
}
