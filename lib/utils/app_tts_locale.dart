import '../i18n/app_i18n.dart';

/// Código ISO 639-1 para Whisper e parâmetro `locale` das Cloud Functions.
String appLocaleApiCode(AppLang lang) => lang.name;

/// Locale BCP-47 preferido para [FlutterTts.setLanguage].
String appTtsLocaleCode(AppLang lang) {
  switch (lang) {
    case AppLang.pt:
      return 'pt-BR';
    case AppLang.en:
      return 'en-US';
    case AppLang.es:
      return 'es-ES';
    case AppLang.fr:
      return 'fr-FR';
    case AppLang.de:
      return 'de-DE';
    case AppLang.it:
      return 'it-IT';
    case AppLang.hi:
      return 'hi-IN';
    case AppLang.id:
      return 'id-ID';
    case AppLang.ja:
      return 'ja-JP';
    case AppLang.ko:
      return 'ko-KR';
    case AppLang.ru:
      return 'ru-RU';
    case AppLang.tr:
      return 'tr-TR';
    case AppLang.zh:
      return 'zh-CN';
  }
}

/// Fallbacks se o motor TTS do aparelho não tiver o locale exato.
List<String> appTtsLocaleFallbacks(AppLang lang) {
  final primary = appTtsLocaleCode(lang);
  final base = primary.split('-').first;
  return [primary, base, 'en-US', 'en'];
}
