import 'package:flutter/material.dart';

import '../services/portal_layout_prefs.dart';

/// Fundo do portal (logado): automático 18h30–6h ou manual nas Preferências.
abstract final class PortalTimeOfDay {
  PortalTimeOfDay._();

  /// Céu/nuvens — login deslogado e cadastro inicial.
  static const backgroundCloudSky =
      'assets/onboarding/cloud_sky_background.png';
  /// Dia no portal (logado): mesmo fundo do cadastro.
  static const backgroundDay = backgroundCloudSky;
  static const backgroundNight = 'assets/onboarding/background_night.png';
  static const backgroundLoading = 'assets/onboarding/background_loading.png';
  /// Céu com balão — telas de login (app e onboarding).
  static const backgroundLogin =
      'assets/onboarding/login_balloon_background.png';
  static const nightTextColor = Color(0xFFDDF3FF);
  static const nightOutlinedTextColor = Colors.white;
  static const nightTextOutlineShadows = [
    Shadow(blurRadius: 1.6, color: Color(0xCC273044), offset: Offset(1, 0)),
    Shadow(blurRadius: 1.6, color: Color(0xCC273044), offset: Offset(-1, 0)),
    Shadow(blurRadius: 1.6, color: Color(0xCC273044), offset: Offset(0, 1)),
    Shadow(blurRadius: 1.6, color: Color(0xCC273044), offset: Offset(0, -1)),
    Shadow(blurRadius: 5, color: Color(0xAA273044), offset: Offset(0, 1)),
  ];

  /// `true` no modo noturno (manual ou automático).
  static bool isNight(DateTime at) =>
      PortalLayoutPrefs.instance.resolveIsNight(at);

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
    if (PortalLayoutPrefs.isNightByClock(at)) {
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
