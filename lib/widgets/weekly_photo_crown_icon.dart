import 'package:flutter/material.dart';

/// Coroa (PNG com alpha) para “Princesa / Príncipe da Semana” e avisos de sorteio.
class WeeklyPhotoCrownIcon extends StatelessWidget {
  const WeeklyPhotoCrownIcon({super.key, this.size = 24});

  static const String assetPath = 'assets/weekly_photo/crown.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Icon(
          Icons.workspace_premium_rounded,
          size: size * 0.92,
          color: const Color(0xFFE6B422),
        ),
      ),
    );
  }
}
