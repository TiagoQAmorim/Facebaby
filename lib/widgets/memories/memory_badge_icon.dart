import 'package:flutter/material.dart';
import '../../i18n/app_i18n.dart';
import '../../models/memory_badge.dart';
import '../../theme/app_theme.dart';

/// [circle] — grelha do Livro de memórias (badge redonda + título abaixo).
/// [original] — detalhe: arte da badge em formato quadrangular (sem recorte circular).
enum MemoryBadgeIconShape { circle, original }

class MemoryBadgeIcon extends StatelessWidget {
  final MemoryBadge badge;
  final bool muted;
  final double size;
  final MemoryBadgeIconShape shape;

  /// Fundo do disco quando [muted] — preto/branco na grelha até haver foto.
  static const Color mutedDiskBackground = Color(0xFFDCDDE3);

  /// Diâmetro (lado do layout) da badge circular na grelha: [size] é o lado do artefato PNG interno (+ padding).
  static double circularLayoutExtent(double size) => size + 10;

  const MemoryBadgeIcon({
    super.key,
    required this.badge,
    this.muted = false,
    this.size = 24,
    this.shape = MemoryBadgeIconShape.circle,
  });

  /// Cor de ícone/texto derivada da tonalidade da própria badge (evita tudo roxo de [AppTheme.primary]).
  static Color accentForeground(MemoryBadge badge, {required bool muted}) {
    if (muted) return Colors.black.withAlpha(120);
    final base = badge.defaultColor;
    return Color.lerp(base, AppTheme.textPrimary, 0.58)!;
  }

  @override
  Widget build(BuildContext context) {
    final fg = accentForeground(badge, muted: muted);
    final bg = muted ? mutedDiskBackground : badge.defaultColor.withAlpha(226);
    final assetPath = 'assets/memories/badges/${badge.iconName}.png';
    final outerR = circularLayoutExtent(size) / 2;
    final squareSide = circularLayoutExtent(size);
    const originalRadius = 10.0;

    if (badge.isMonthlyBadge && badge.monthNumber != null) {
      final n = badge.monthNumber!;
      final s = S.of(context);
      final unitLabel = n == 1 ? s.memoryBadgeMonthUnitSingular : s.memoryBadgeMonthUnitPlural;
      final inner = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$n',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: size * 0.55, height: 1, color: fg),
          ),
          Text(
            unitLabel,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.22, height: 1, color: fg.withAlpha(160)),
          ),
        ],
      );
      if (shape == MemoryBadgeIconShape.original) {
        return Container(
          width: squareSide,
          height: squareSide,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(originalRadius),
            border: Border.all(color: Colors.white.withAlpha(200)),
          ),
          alignment: Alignment.center,
          child: inner,
        );
      }
      return Container(
        width: squareSide,
        height: squareSide,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(200)),
        ),
        alignment: Alignment.center,
        child: inner,
      );
    }

    if (badge.category == 'birthday' && badge.yearNumber != null) {
      final y = badge.yearNumber!;
      final cake = Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.cake_rounded, size: size * 0.75, color: fg.withAlpha(200)),
          Positioned(
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(220),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$y',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: size * 0.28, height: 1, color: fg),
              ),
            ),
          ),
        ],
      );
      if (shape == MemoryBadgeIconShape.original) {
        return Container(
          width: squareSide,
          height: squareSide,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(originalRadius),
            border: Border.all(color: Colors.white.withAlpha(200)),
          ),
          alignment: Alignment.center,
          child: cake,
        );
      }
      return Container(
        width: squareSide,
        height: squareSide,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(200)),
        ),
        alignment: Alignment.center,
        child: cake,
      );
    }

    final imageChild = muted
        ? Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            color: Colors.black.withAlpha(140),
            colorBlendMode: BlendMode.darken,
            errorBuilder: (_, __, ___) =>
                Icon(badge.icon ?? Icons.auto_awesome_rounded, size: size * 0.92, color: fg),
          )
        : Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) =>
                Icon(badge.icon ?? Icons.auto_awesome_rounded, size: size * 0.92, color: fg),
          );

    if (shape == MemoryBadgeIconShape.original) {
      return Container(
        width: squareSide,
        height: squareSide,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(originalRadius),
          border: Border.all(color: Colors.white.withAlpha(200)),
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: imageChild,
        ),
      );
    }

    return CircleAvatar(
      radius: outerR,
      backgroundColor: bg,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: imageChild,
      ),
    );
  }
}
