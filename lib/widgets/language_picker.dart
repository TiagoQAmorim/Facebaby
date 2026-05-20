import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';

/// Idiomas disponíveis no seletor (Definições e Preferências do perfil).
class AppLanguageOption {
  const AppLanguageOption({
    required this.lang,
    required this.label,
    required this.flag,
  });

  final AppLang lang;
  final String label;
  final String flag;
}

const List<AppLanguageOption> kAppLanguagePickerOptions = [
  AppLanguageOption(
      lang: AppLang.pt, label: 'Português (Brasil)', flag: '🇧🇷'),
  AppLanguageOption(lang: AppLang.en, label: 'English (US)', flag: '🇺🇸'),
  AppLanguageOption(lang: AppLang.es, label: 'Español (ES)', flag: '🇪🇸'),
  AppLanguageOption(lang: AppLang.fr, label: 'Français (FR)', flag: '🇫🇷'),
  AppLanguageOption(lang: AppLang.de, label: 'Deutsch (DE)', flag: '🇩🇪'),
  AppLanguageOption(lang: AppLang.it, label: 'Italiano (IT)', flag: '🇮🇹'),
];

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppI18nScope.of(context);
    final flag = kAppLanguagePickerOptions
        .firstWhere(
          (o) => o.lang == controller.lang,
          orElse: () => kAppLanguagePickerOptions.first,
        )
        .flag;

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

AppLanguageOption appLanguageOptionFor(AppLang lang) {
  return kAppLanguagePickerOptions.firstWhere(
    (o) => o.lang == lang,
    orElse: () => kAppLanguagePickerOptions.first,
  );
}

/// Item de lista nas Preferências: toque expande e mostra bandeiras.
class LanguagePreferencePicker extends StatefulWidget {
  const LanguagePreferencePicker({super.key});

  @override
  State<LanguagePreferencePicker> createState() =>
      _LanguagePreferencePickerState();
}

class _LanguagePreferencePickerState extends State<LanguagePreferencePicker> {
  final _expansion = ExpansionTileController();

  void _select(AppLang lang) {
    AppI18nScope.of(context).setLang(lang);
    _expansion.collapse();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final controller = AppI18nScope.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selected = controller.lang;
        final current = appLanguageOptionFor(selected);

        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            controller: _expansion,
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            expandedAlignment: Alignment.centerLeft,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Text(current.flag, style: const TextStyle(fontSize: 20)),
            ),
            title: Text(
              s.language,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              current.label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black.withAlpha(140),
              ),
            ),
            children: [
              for (var i = 0; i < kAppLanguagePickerOptions.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, color: Colors.black.withAlpha(24)),
                _LanguageListTile(
                  option: kAppLanguagePickerOptions[i],
                  selected: selected == kAppLanguagePickerOptions[i].lang,
                  onSelect: _select,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Lista completa de idiomas (ex.: bottom sheet na Home).
class LanguageSelectionList extends StatelessWidget {
  const LanguageSelectionList({
    super.key,
    this.onSelect,
  });

  /// Se definido, substitui [AppLanguageController.setLang] (ex.: fechar o sheet).
  final void Function(AppLang lang)? onSelect;

  @override
  Widget build(BuildContext context) {
    final controller = AppI18nScope.of(context);
    final select = onSelect ?? controller.setLang;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selected = controller.lang;
        return Column(
          children: [
            for (var i = 0; i < kAppLanguagePickerOptions.length; i++) ...[
              if (i > 0)
                Divider(height: 1, color: Colors.black.withAlpha(24)),
              _LanguageListTile(
                option: kAppLanguagePickerOptions[i],
                selected: selected == kAppLanguagePickerOptions[i].lang,
                onSelect: select,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LanguageListTile extends StatelessWidget {
  const _LanguageListTile({
    required this.option,
    required this.selected,
    required this.onSelect,
  });

  final AppLanguageOption option;
  final bool selected;
  final void Function(AppLang lang) onSelect;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white,
        child: Text(option.flag, style: const TextStyle(fontSize: 18)),
      ),
      title: Text(
        option.label,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle, color: Colors.green, size: 22)
          : null,
      onTap: selected ? null : () => onSelect(option.lang),
    );
  }
}

Future<void> showLanguagePicker(BuildContext context) async {
  final s = S.of(context);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(s.language,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: const Text(
                    'Português • English • Español • Français • Deutsch • Italiano'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LanguageSelectionList(
                  onSelect: (lang) {
                    AppI18nScope.of(context).setLang(lang);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
