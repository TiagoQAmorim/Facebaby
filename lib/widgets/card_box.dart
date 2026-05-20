import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CardBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool important;
  final Color? color;
  final bool showShadow;

  const CardBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.important = false,
    this.color,
    this.showShadow = true,
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
        color: color ?? AppTheme.card,
        borderRadius: BorderRadius.circular(24),
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
