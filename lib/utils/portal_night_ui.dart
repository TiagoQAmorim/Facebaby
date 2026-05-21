import 'package:flutter/material.dart';

import '../services/portal_layout_prefs.dart';
import '../theme/app_theme.dart';
import 'portal_time_of_day.dart';

/// Estilos reutilizáveis para ecrãs do portal em modo noturno.
abstract final class PortalNightUi {
  PortalNightUi._();

  static bool isNightNow() => PortalTimeOfDay.isNight(DateTime.now());

  static AppBar appBar(String title, {bool? night}) {
    final n = night ?? isNightNow();
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: n ? PortalTimeOfDay.nightOutlinedTextColor : null,
          shadows: n ? PortalTimeOfDay.nightTextOutlineShadows : null,
        ),
      ),
      iconTheme: n
          ? const IconThemeData(color: PortalTimeOfDay.nightOutlinedTextColor)
          : null,
      actionsIconTheme: n
          ? const IconThemeData(color: PortalTimeOfDay.nightOutlinedTextColor)
          : null,
      foregroundColor: n ? PortalTimeOfDay.nightOutlinedTextColor : null,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    );
  }

  static TextStyle titleStyle(bool night, {double fontSize = 17}) {
    if (!night) {
      return TextStyle(fontWeight: FontWeight.w900, fontSize: fontSize);
    }
    return TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: fontSize,
      color: PortalTimeOfDay.nightOutlinedTextColor,
      shadows: PortalTimeOfDay.nightTextOutlineShadows,
    );
  }

  static TextStyle bodyStyle(bool night, {double fontSize = 14}) {
    if (!night) return TextStyle(fontSize: fontSize);
    return TextStyle(
      fontSize: fontSize,
      color: PortalTimeOfDay.nightOutlinedTextColor,
      shadows: PortalTimeOfDay.nightTextOutlineShadows,
    );
  }

  static TextStyle sectionStyle(bool night) {
    if (!night) return const TextStyle();
    return TextStyle(
      color: PortalTimeOfDay.nightTextColor,
      shadows: PortalTimeOfDay.nightTextOutlineShadows,
    );
  }

  static ({Color label, Color unselected, Color indicator}) tabColors(
    bool night, {
    required Color dayAccent,
  }) {
    if (!night) {
      return (
        label: dayAccent,
        unselected: Colors.black.withAlpha(120),
        indicator: dayAccent,
      );
    }
    return (
      label: PortalTimeOfDay.nightOutlinedTextColor,
      unselected: PortalTimeOfDay.nightOutlinedTextColor.withAlpha(200),
      indicator: PortalTimeOfDay.nightOutlinedTextColor,
    );
  }

  static TextStyle alertTitleStyle(bool night, {double fontSize = 15}) {
    if (!night) {
      return TextStyle(fontWeight: FontWeight.w800, fontSize: fontSize);
    }
    return TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: fontSize,
      color: PortalTimeOfDay.nightOutlinedTextColor,
      shadows: PortalTimeOfDay.nightTextOutlineShadows,
    );
  }

  static TextStyle alertSubtitleStyle(bool night, {double fontSize = 12}) {
    if (!night) {
      return TextStyle(fontSize: fontSize, color: Colors.black.withAlpha(130));
    }
    return TextStyle(
      fontSize: fontSize,
      height: 1.25,
      color: PortalTimeOfDay.nightOutlinedTextColor,
      shadows: PortalTimeOfDay.nightTextOutlineShadows,
    );
  }

  static Color alertIconColor(bool night, Color dayAccent) =>
      night ? PortalTimeOfDay.nightOutlinedTextColor : dayAccent.withAlpha(220);

  static Color chevronColor(bool night) =>
      night ? PortalTimeOfDay.nightOutlinedTextColor : Colors.black.withAlpha(90);

  static Color iconOnNight(bool night, Color dayColor) =>
      night ? PortalTimeOfDay.nightOutlinedTextColor : dayColor;

  /// Título em [CardBox] / fundo claro — sempre cores do modo diurno.
  static TextStyle cardTitleStyle({double fontSize = 17}) => TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
        color: Colors.black.withAlpha(230),
      );

  /// Subtítulo em [CardBox] — cinza, sem contorno.
  static TextStyle cardSubtitleStyle({double fontSize = 13}) => TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: Colors.black.withAlpha(130),
      );

  static Color cardChevronColor() => Colors.black.withAlpha(90);

  /// Títulos no painel semitransparente da Home («Últimas memórias», «Ver todos»).
  static const homeFrostedHeadingGray = Color(0xFF5B6B8C);

  /// Likes, nome e idade na Foto da Semana (Home, modo noturno).
  static const homeFrostedDetailBlue = Color(0xFF1A5278);

  /// Fundo claro em telas de detalhe (ex.: memória/badge) quando o portal está noturno.
  static Color detailPageBackground(bool night) =>
      night ? AppTheme.background : Colors.transparent;

  /// Tema para formulários em [CardBox]: dropdown com fundo branco opaco e texto escuro.
  static ThemeData cardFormTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      canvasColor: AppTheme.card,
      dialogTheme: DialogThemeData(backgroundColor: AppTheme.card),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(AppTheme.card),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shadowColor: WidgetStateProperty.all(Colors.black26),
          elevation: WidgetStateProperty.all(6),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.card,
        labelStyle: TextStyle(color: AppTheme.textSecondary),
        floatingLabelStyle: TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }

  /// Envolve [child] e reconstrói quando o modo dia/noite muda.
  static Widget listen(Widget Function(BuildContext context, bool night) builder) {
    return ListenableBuilder(
      listenable: PortalLayoutPrefs.instance,
      builder: (context, _) => builder(context, isNightNow()),
    );
  }
}
