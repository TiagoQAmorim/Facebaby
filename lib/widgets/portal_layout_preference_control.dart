import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../services/portal_layout_prefs.dart';
import '../utils/portal_time_of_day.dart';

/// Seletor Auto / Diurno / Noturno (Preferências › Meu Perfil).
class PortalLayoutPreferenceControl extends StatelessWidget {
  const PortalLayoutPreferenceControl({super.key});

  Future<void> _applyMode(BuildContext context, PortalLayoutMode mode) async {
    await PortalLayoutPrefs.instance.setMode(mode);
    if (!context.mounted) return;
    unawaited(PortalTimeOfDay.precacheBackgrounds(context));
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
