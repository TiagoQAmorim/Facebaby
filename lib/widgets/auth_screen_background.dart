import 'package:flutter/material.dart';

/// Cor de fallback alinhada ao céu do artwork de onboarding.
const kAuthScreenSkyFallback = Color(0xFFB8D9EE);

/// Fundo das telas de login/cadastro — preenche o ecrã sem faixas vazias.
class AuthScreenBackground extends StatelessWidget {
  const AuthScreenBackground({
    super.key,
    required this.asset,
    this.fallbackColor = kAuthScreenSkyFallback,
    this.alignment = Alignment.bottomCenter,
  });

  final String asset;
  final Color fallbackColor;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: fallbackColor),
        Positioned.fill(
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: alignment,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
