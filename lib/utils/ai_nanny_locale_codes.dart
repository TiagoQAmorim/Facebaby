import '../i18n/app_i18n.dart';

/// Códigos BCP 47 para o parser / Cloud Function.
abstract final class AiNannyLocaleCodes {
  static String fromAppLang(AppLang lang) => switch (lang) {
        AppLang.pt => 'pt_BR',
        AppLang.en => 'en_US',
        AppLang.es => 'es_ES',
        AppLang.it => 'it_IT',
        AppLang.fr => 'fr_FR',
        AppLang.de => 'de_DE',
        AppLang.hi => 'hi_IN',
        AppLang.id => 'id_ID',
        AppLang.ja => 'ja_JP',
        AppLang.ko => 'ko_KR',
        AppLang.ru => 'ru_RU',
        AppLang.tr => 'tr_TR',
        AppLang.zh => 'zh_CN',
      };

  static const supportedCore = ['pt_BR', 'en_US', 'es_ES', 'it_IT', 'fr_FR', 'de_DE'];
}
