import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppI18nScope.of(context);
    final flag = switch (controller.lang) {
      AppLang.pt => '🇧🇷',
      AppLang.en => '🇺🇸',
      AppLang.es => '🇪🇸',
      AppLang.fr => '🇫🇷',
      AppLang.de => '🇩🇪',
      AppLang.it => '🇮🇹',
      AppLang.hi => '🇮🇳',
      AppLang.id => '🇮🇩',
      AppLang.ja => '🇯🇵',
      AppLang.ko => '🇰🇷',
      AppLang.ru => '🇷🇺',
      AppLang.tr => '🇹🇷',
      AppLang.zh => '🇨🇳',
    };

    return IconButton(
      tooltip: S.of(context).language,
      onPressed: () => showLanguagePicker(context),
      icon: CircleAvatar(
        radius: 14,
        backgroundColor: Colors.white,
        child: Text(flag, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

Future<void> showLanguagePicker(BuildContext context) async {
  final controller = AppI18nScope.of(context);
  final s = S.of(context);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      Widget option({required AppLang lang, required String label, required String flag}) {
        final selected = controller.lang == lang;
        return ListTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Text(flag, style: const TextStyle(fontSize: 18)),
          ),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          trailing: selected ? const Icon(Icons.check, color: Colors.green) : null,
          onTap: () {
            controller.setLang(lang);
            Navigator.of(context).pop();
          },
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(s.language, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: const Text('Português • English • Español • Français • Deutsch • Italiano • 日本語 • 한국어 • 中文'),
              ),
              option(lang: AppLang.pt, label: 'Português (Brasil)', flag: '🇧🇷'),
              option(lang: AppLang.en, label: 'English (US)', flag: '🇺🇸'),
              option(lang: AppLang.es, label: 'Español (ES)', flag: '🇪🇸'),
              option(lang: AppLang.fr, label: 'Français (FR)', flag: '🇫🇷'),
              option(lang: AppLang.de, label: 'Deutsch (DE)', flag: '🇩🇪'),
              option(lang: AppLang.it, label: 'Italiano (IT)', flag: '🇮🇹'),
              option(lang: AppLang.ja, label: '日本語 (JP)', flag: '🇯🇵'),
              option(lang: AppLang.ko, label: '한국어 (KR)', flag: '🇰🇷'),
              option(lang: AppLang.zh, label: '中文 (简体)', flag: '🇨🇳'),
            ],
          ),
        ),
      );
    },
  );
}

