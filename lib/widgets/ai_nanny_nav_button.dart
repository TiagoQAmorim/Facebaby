import 'package:flutter/material.dart';

/// Ícone central do footer — IA Babá com glow rosa/lilás.
class AiNannyNavButton extends StatelessWidget {
  const AiNannyNavButton({
    super.key,
    required this.selected,
    required this.label,
    this.locked = false,
    this.compact = false,
  });

  final bool selected;
  final String label;
  final bool locked;
  final bool compact;

  static const _asset = 'assets/ai/ia_baba_button.png';

  @override
  Widget build(BuildContext context) {
    final circleSize = compact ? 52.0 : 56.0;
    final labelSize = compact ? 10.0 : 10.5;
    final labelGap = compact ? 2.0 : 3.0;
    final glow = selected
        ? [
            BoxShadow(
              color: const Color(0xFFE91E8C).withAlpha(90),
              blurRadius: 18,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: const Color(0xFF9C27B0).withAlpha(70),
              blurRadius: 24,
              spreadRadius: 0,
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0xFFCE93D8).withAlpha(45),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFF8FC),
                boxShadow: glow,
              ),
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: Opacity(
                  opacity: locked ? 0.55 : 1,
                  child: Image.asset(
                    _asset,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.auto_awesome_rounded,
                      color: selected
                          ? const Color(0xFF8E24AA)
                          : const Color(0xFFAB47BC),
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            if (locked)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFCE93D8)),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: Colors.black.withAlpha(170),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: labelGap),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: labelSize,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? const Color(0xFF6A1B9A)
                : Colors.black.withAlpha(140),
          ),
        ),
      ],
    );
  }
}
