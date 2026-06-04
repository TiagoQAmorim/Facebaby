import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aiNannyWelcomeMessage is localized (not Portuguese fallback)', () {
    const cases = <AppLang, String>{
      AppLang.en: 'AI Nanny',
      AppLang.es: 'IA Niñera',
      AppLang.fr: 'IA Nounou',
      AppLang.de: 'KI-Babysitterin',
      AppLang.it: 'IA Tata',
    };

    for (final entry in cases.entries) {
      final msg = S(entry.key).aiNannyWelcomeMessage;
      expect(msg, contains(entry.value), reason: entry.key.name);
      expect(msg, isNot(contains('IA Babá')), reason: entry.key.name);
      expect(msg, isNot(contains('Sou sua companheira')), reason: entry.key.name);
    }
  });
}
