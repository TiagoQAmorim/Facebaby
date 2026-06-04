import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/services/ai/ai_bubble_routine_insights.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unified brief combines title, today, and curiosity prefs key', () async {
    final strings = S(AppLang.pt);
    final text = await AiBubbleRoutineInsights.buildUnifiedDailyBrief(
      babyId: null,
      babyName: 'Ana',
      babySex: 'F',
      birthDate: DateTime(2024, 1, 1),
      strings: strings,
      todayDailyText: 'Resumo de hoje para teste.',
    );
    expect(text, isNotNull);
    expect(text, contains(strings.aiBubbleDailyBriefTitle));
    expect(text, contains('Resumo de hoje para teste.'));
    expect(AiBubbleRoutineInsights.prefsKey, 'daily_brief_unified');
  });
}
