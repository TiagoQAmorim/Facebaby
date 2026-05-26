import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AdminTheme {
  static const pink = Color(0xFFE91E8C);
  static const purple = Color(0xFF7B1FA2);
  static const sky = Color(0xFFB8D9EE);
  static const mint = Color(0xFFE8F8F5);
  static const cardBg = Colors.white;

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: pink,
        primary: pink,
        secondary: purple,
        surface: cardBg,
      ),
    );
    return base.copyWith(
      textTheme: GoogleFonts.nunitoTextTheme(base.textTheme),
      scaffoldBackgroundColor: const Color(0xFFF4F7FB),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: pink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(true),
        thickness: WidgetStateProperty.all(10),
        radius: const Radius.circular(6),
        crossAxisMargin: 4,
        mainAxisMargin: 4,
        thumbColor: WidgetStateProperty.all(purple.withValues(alpha: 0.55)),
        trackColor: WidgetStateProperty.all(Colors.black.withValues(alpha: 0.06)),
      ),
    );
  }
}
