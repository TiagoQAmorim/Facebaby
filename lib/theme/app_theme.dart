import 'package:flutter/material.dart';

class AppTheme {
  // Paleta base (neutra; rosa só pontual se precisar do token legacy).
  static const primaryPink = Color(0xFFF94D9B);
  static const primaryPurple = Color(0xFF8D5CF6);
  static const mint = Color(0xFF7EDDD3);
  static const babyBlue = Color(0xFF74B9FF);
  static const lavender = Color(0xFFEEE5FF);

  /// Botões preenchidos / destaque principal (cinza-azulado, sem rosa).
  static const ctaPrimary = Color(0xFF5B6B8C);

  /// Fundo geral do app (eco frio-quente, menos “cinzento hospital”).
  static const background = Color(0xFFF7F8FC);
  static const card = Color(0xFFFFFFFF);

  /// Fundos suaves em cards/avatars (nome histórico `softPink`; tom neutro).
  static const softPink = Color(0xFFE4E7EC);
  static const softPurple = Color(0xFFE8EAF0);
  static const softMint = Color(0xFFE4FAF6);

  static const textPrimary = Color(0xFF1F1F2E);
  static const textSecondary = Color(0xFF74717F);
  static const textMuted = Color(0xFFA8A3B5);

  // Backwards-compat aliases for existing code.
  static const primary = primaryPurple;
  /// Acento secundário neutro (ícones, gráficos) — não usar rosa aqui.
  static const secondary = Color(0xFF607D8B);
  static const green = mint;
  static const yellow = Color(0xFFFFB84D);
  static const text = textPrimary;

  /// Hub Amamentação + alertas «Mais › Alertas» (mantém violeta legível sobre fundo claro).
  static const feedingAlertAccent = Color(0xFF7B5FB8);

  /// Material 3: pinta thumb/track do Switch quando «ligado», independentemente do `ColorScheme`.
  static SwitchThemeData switchThemeColored(Color accent) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accent;
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accent.withAlpha(100);
        return null;
      }),
    );
  }

  /// Padding horizontal padrão das páginas (reduzido para ganhar área útil).
  static const double pageHPadding = 16;

  /// Fundo principal do `Scaffold` e base dos gradientes (pastel por sexo do bebê).
  static Color backdropTintForSex(String sex) {
    const pink = Color(0xFFFFE8EF);
    const blue = Color(0xFFEAF2FF);
    return (sex == 'M') ? blue : pink;
  }

  /// Gradiente da Home: mais ar no topo, toque de cor mais baixo para não ficar “tinta lavada”.
  static LinearGradient homeBodyGradient(Color tint) {
    return LinearGradient(
      begin: const Alignment(0, -1.08),
      end: const Alignment(0.06, 1.04),
      colors: [
        Color.lerp(const Color(0xFFFDFDFE), tint, 0.26)!,
        Color.lerp(const Color(0xFFF9FAFD), tint, 0.17)!,
        Color.lerp(tint, const Color(0xFFF6F8FC), 0.48)!,
      ],
      stops: const [0.0, 0.48, 1.0],
    );
  }

  /// Gradiente discreto atrás das tabs (corpo principal): quase neutro + sugestão da tinta em baixo.
  static LinearGradient shellBackdropGradient(Color tint) {
    const top = Color(0xFFFAFBFE);
    const mid = Color(0xFFF7F8FC);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(top, tint, 0.045)!,
        Color.lerp(mid, tint, 0.09)!,
        Color.lerp(const Color(0xFFF4F6FA), tint, 0.14)!,
      ],
      stops: const [0.0, 0.52, 1.0],
    );
  }

  /// Barra inferior harmonizada com a tint escolhida sem peso visual forte.
  static Color navigationBarSurfaceForTint(Color tint) {
    final blended =
        Color.lerp(const Color(0xFFF9FAFD), tint, 0.068) ?? const Color(0xFFF9FAFD);
    return blended.withAlpha(252);
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: textPrimary,
            displayColor: textPrimary,
          ),
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(seedColor: ctaPrimary).copyWith(
        primary: ctaPrimary,
        secondary: primaryPurple,
        tertiary: mint,
        surface: card,
        onSurface: textPrimary,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: card,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 84,
        backgroundColor: Color.lerp(background, const Color(0xFFFFF5F8), 0.12)!,
        indicatorColor: primaryPink.withAlpha(52),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ctaPrimary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, height: 1.2),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ctaPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, height: 1.2),
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          side: BorderSide(color: ctaPrimary.withAlpha(90)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ctaPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
