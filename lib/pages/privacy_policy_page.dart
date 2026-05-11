import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_locale.dart';
import '../i18n/app_i18n.dart';
import '../theme/app_theme.dart';
import '../widgets/legal_document_view.dart';

String _privacyAssetForLang(AppLang lang) {
  final tag = switch (lang) {
    AppLang.pt => 'pt_BR',
    AppLang.en => 'en_US',
    AppLang.es => 'es_ES',
    AppLang.fr => 'fr_FR',
    AppLang.de => 'de_DE',
    AppLang.it => 'it_IT',
    AppLang.hi => 'hi_IN',
    AppLang.id => 'id_ID',
    AppLang.ja => 'ja_JP',
    AppLang.ko => 'ko_KR',
    AppLang.ru => 'ru_RU',
    AppLang.tr => 'tr_TR',
    AppLang.zh => 'zh_CN',
  };
  return 'assets/privacy/privacy_$tag.txt';
}

Future<String> _loadPrivacyBody(AppLang lang) async {
  final primary = _privacyAssetForLang(lang);
  for (final path in <String>[primary, 'assets/privacy/privacy_en_US.txt']) {
    try {
      return await rootBundle.loadString(path);
    } catch (_) {
      continue;
    }
  }
  return '';
}

/// Política de privacidade por idioma (`assets/privacy/`).
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.settingsPrivacyPolicy)),
      body: ListenableBuilder(
        listenable: kAppLanguage,
        builder: (context, _) {
          final lang = kAppLanguage.lang;
          return FutureBuilder<String>(
            key: ValueKey<Object>(lang),
            future: _loadPrivacyBody(lang),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final text = snap.data ?? '';
              if (text.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(s.termsLoadError, textAlign: TextAlign.center),
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppTheme.pageHPadding, 20, AppTheme.pageHPadding, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: LegalDocumentView(rawText: text),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
