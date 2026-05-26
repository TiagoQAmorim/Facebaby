import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CardBox extends StatelessWidget {
  /// Alinhado ao header da Home e cartões do portal.
  static const int frostedFillAlpha = 200;
  static const int frostedBorderAlpha = 92;

  static Color get frostedFill => Colors.white.withAlpha(frostedFillAlpha);

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool important;
  final Color? color;
  final bool showShadow;

  /// Fundo branco levemente transparente (céu do portal visível por trás).
  final bool frosted;

  const CardBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.important = false,
    this.color,
    this.showShadow = true,
    this.frosted = false,
  });

  @override
  Widget build(BuildContext context) {
    final shadowColor = important
        ? AppTheme.ctaPrimary.withAlpha(35)
        : AppTheme.ctaPrimary.withAlpha(22);
    final blur = important ? 40.0 : 30.0;
    final dy = important ? 16.0 : 12.0;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (frosted ? frostedFill : AppTheme.card),
        borderRadius: BorderRadius.circular(24),
        border: frosted
            ? Border.all(color: Colors.white.withAlpha(frostedBorderAlpha))
            : null,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: blur,
                  offset: Offset(0, dy),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}
