import 'package:flutter/material.dart';

import '../../models/memory_badge.dart';
import '../../theme/app_theme.dart';
import '../../utils/portal_layout.dart';

/// Cor do título da badge na grelha do Livro de memórias: baseada na paleta da badge, com contraste em fundo claro.
Color memoryBadgeGridTitleColor(MemoryBadge badge, {bool muted = false}) {
  final pull = muted ? 0.48 : 0.32;
  var c = Color.lerp(badge.defaultColor, AppTheme.textPrimary, pull)!;
  if (c.computeLuminance() > 0.58) {
    c = Color.lerp(c, AppTheme.textPrimary, 0.42)!;
  }
  if (muted) {
    c = Color.lerp(c, AppTheme.textSecondary, 0.22)!;
  }
  return c;
}

TextStyle memoryBadgeGridTitleStyle(
  BuildContext context,
  MemoryBadge badge, {
  bool muted = false,
}) {
  return TextStyle(
    // Aumenta o título sem estourar o layout: o texto já usa maxLines=2 + ellipsis nos cards.
    fontSize: portalSp(context, muted ? 13.2 : 14.6),
    fontWeight: FontWeight.w800,
    color: memoryBadgeGridTitleColor(badge, muted: muted),
    height: 1.06,
    letterSpacing: -0.2,
  );
}
