import 'package:flutter/material.dart';

/// Fundo do portal (logado) conforme o relógio do dispositivo: noite 18h30–6h.
abstract final class PortalTimeOfDay {
  PortalTimeOfDay._();

  static const backgroundDay = 'assets/onboarding/background_day.png';
  static const backgroundNight = 'assets/onboarding/background_night.png';
  static const backgroundLoading = 'assets/onboarding/background_loading.png';
  static const backgroundLogin = 'assets/onboarding/login_balloon_background.png';
  static const nightTextColor = Color(0xFFDDF3FF);

  /// `true` entre 18:30 (inclusive) e 06:00 (exclusive).
  static bool isNight(DateTime at) {
    final h = at.hour;
    return h < 6 || h > 18 || (h == 18 && at.minute >= 30);
  }

  static String backgroundAsset(DateTime at) =>
      isNight(at) ? backgroundNight : backgroundDay;

  static const List<String> cachedBackgroundAssets = [
    backgroundDay,
    backgroundNight,
    backgroundLoading,
    backgroundLogin,
  ];

  static Future<void> precacheBackgrounds(BuildContext context) {
    return Future.wait<void>(
      cachedBackgroundAssets.map(
        (asset) => precacheImage(AssetImage(asset), context),
      ),
    );
  }

  /// Próxima transição dia ↔ noite (6:00 ou 18:30 local).
  static DateTime nextTransitionAfter(DateTime at) {
    final day6 = DateTime(at.year, at.month, at.day, 6);
    final day1830 = DateTime(at.year, at.month, at.day, 18, 30);
    if (isNight(at)) {
      return at.isBefore(day6) ? day6 : day6.add(const Duration(days: 1));
    }
    return at.isBefore(day1830)
        ? day1830
        : day1830.add(const Duration(days: 1));
  }

  static Duration delayUntilNextTransition(DateTime at) {
    final next = nextTransitionAfter(at);
    final d = next.difference(at);
    return d <= Duration.zero ? const Duration(minutes: 1) : d;
  }
}
