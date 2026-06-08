import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../services/portal_layout_prefs.dart';
import '../theme/app_theme.dart';
import '../utils/portal_time_of_day.dart';

IconData portalLayoutModeIcon(PortalLayoutMode mode) {
  switch (mode) {
    case PortalLayoutMode.automatic:
      return Icons.brightness_auto_outlined;
    case PortalLayoutMode.day:
      return Icons.wb_sunny_outlined;
    case PortalLayoutMode.night:
      return Icons.nightlight_round_outlined;
  }
}

String portalLayoutModeLabel(S s, PortalLayoutMode mode) {
  switch (mode) {
    case PortalLayoutMode.automatic:
      return s.profileLayoutAutomatic;
    case PortalLayoutMode.day:
      return s.profileLayoutDay;
    case PortalLayoutMode.night:
      return s.profileLayoutNight;
  }
}

Future<void> _applyPortalLayoutMode(
  BuildContext context,
  PortalLayoutMode mode,
) async {
  await PortalLayoutPrefs.instance.setMode(mode);
  if (!context.mounted) return;
  unawaited(PortalTimeOfDay.precacheBackgrounds(context));
}

Future<void> showPortalLayoutPicker(BuildContext context) async {
  final s = S.of(context);
  final current = PortalLayoutPrefs.instance.mode;

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
                title: Text(
                  s.profileLayoutTitle,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(s.profileLayoutSubtitle),
              ),
              for (final mode in PortalLayoutMode.values)
                ListTile(
                  leading: Icon(portalLayoutModeIcon(mode)),
                  title: Text(portalLayoutModeLabel(s, mode)),
                  trailing: mode == current
                      ? const Icon(Icons.check, color: AppTheme.primaryPurple)
                      : null,
                  onTap: () async {
                    await _applyPortalLayoutMode(context, mode);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Botão compacto para o header da Home (Auto / Diurno / Noturno).
class PortalLayoutToggleButton extends StatelessWidget {
  const PortalLayoutToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return ListenableBuilder(
      listenable: PortalLayoutPrefs.instance,
      builder: (context, _) {
        final mode = PortalLayoutPrefs.instance.mode;

        return IconButton(
          tooltip: portalLayoutModeLabel(s, mode),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          iconSize: 22,
          onPressed: () => showPortalLayoutPicker(context),
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryPurple.withAlpha(44),
            child: Icon(
              portalLayoutModeIcon(mode),
              size: 21,
              color: AppTheme.primaryPurple,
            ),
          ),
        );
      },
    );
  }
}

/// Seletor Auto / Diurno / Noturno (Preferências › Meu Perfil).
class PortalLayoutPreferenceControl extends StatelessWidget {
  const PortalLayoutPreferenceControl({super.key});

  Future<void> _applyMode(BuildContext context, PortalLayoutMode mode) async {
    await _applyPortalLayoutMode(context, mode);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return ListenableBuilder(
      listenable: PortalLayoutPrefs.instance,
      builder: (context, _) {
        final mode = PortalLayoutPrefs.instance.mode;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.profileLayoutTitle,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              s.profileLayoutSubtitle,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black.withAlpha(140),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<PortalLayoutMode>(
              segments: [
                ButtonSegment(
                  value: PortalLayoutMode.automatic,
                  label: Text(s.profileLayoutAutomatic),
                ),
                ButtonSegment(
                  value: PortalLayoutMode.day,
                  label: Text(s.profileLayoutDay),
                ),
                ButtonSegment(
                  value: PortalLayoutMode.night,
                  label: Text(s.profileLayoutNight),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selected) {
                if (selected.isEmpty) return;
                unawaited(_applyMode(context, selected.first));
              },
            ),
          ],
        );
      },
    );
  }
}
