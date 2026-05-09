import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FaceBabySpinner extends StatelessWidget {
  final double size;
  final double strokeWidth;

  const FaceBabySpinner({
    super.key,
    this.size = 28,
    this.strokeWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(color),
        backgroundColor: AppTheme.secondary.withAlpha(35),
      ),
    );
  }
}

class FaceBabyLoadingOverlay extends StatelessWidget {
  final bool visible;
  final String? label;

  const FaceBabyLoadingOverlay({
    super.key,
    required this.visible,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    final t = Theme.of(context);
    final effectiveLabel = (label ?? '').trim().isEmpty ? null : label!.trim();

    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
            child: Container(color: Colors.black.withAlpha(35)),
          ),
        ),
        Center(
          child: SizedBox(
            width: 320,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(245),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFEEE6F6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(18),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: AppTheme.primary.withAlpha(18),
                      padding: const EdgeInsets.all(6),
                      child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DefaultTextStyle(
                      style: t.textTheme.bodyMedium ?? const TextStyle(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Aguarde…', style: TextStyle(fontWeight: FontWeight.w900)),
                          if (effectiveLabel != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              effectiveLabel,
                              style: TextStyle(color: Colors.black.withAlpha(160)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const FaceBabySpinner(size: 26, strokeWidth: 3),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
