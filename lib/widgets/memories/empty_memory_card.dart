import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../i18n/app_i18n.dart';
import '../../models/memory_badge.dart';
import '../../utils/portal_layout.dart';
import 'memory_badge_grid_title.dart';
import 'memory_badge_icon.dart';

/// Slot sem memória: badge + título próximos, sem espaço vazio entre eles.
class EmptyMemoryCard extends StatelessWidget {
  final MemoryBadge badge;
  final VoidCallback onTap;

  const EmptyMemoryCard({super.key, required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final ch = constraints.maxHeight;

        // O Grid define altura fixa por célula; se usarmos `min(cw, ch)` o círculo ignora
        // o espaço do título e pode estourar (faixa amarela "overflowed by ... px").
        const verticalPadding = 8.0 * 2; // Padding do Ink top/bottom
        const gapAfterCircle = 8.0;
        final titleFs = portalSp(context, 11.8);
        final titleBlockH = (titleFs * 2.0 * 1.12); // até 2 linhas
        final availH = (ch - verticalPadding - gapAfterCircle - titleBlockH).clamp(0.0, double.infinity);
        final side = math.min(cw, availH);
        final badgeSize = (side * 0.92).clamp(24.0, 50.0);
        final circleExtent = MemoryBadgeIcon.circularLayoutExtent(badgeSize);
        /// Mini-badge no canto (escala semelhante ao badge sobre a foto em [FilledMemoryCard]).
        final plusBadgeOuter = (circleExtent * 0.42).clamp(22.0, 34.0);
        final plusFontSize = (plusBadgeOuter * 0.52).clamp(15.0, 22.0);

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(Colors.white, badge.defaultColor, 0.11)!,
                    Color.lerp(Colors.white, badge.defaultColor, 0.045)!,
                  ],
                ),
                border: Border.all(color: badge.defaultColor.withAlpha(44)),
                boxShadow: [
                  BoxShadow(
                    color: badge.defaultColor.withAlpha(32),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: circleExtent,
                        height: circleExtent,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            MemoryBadgeIcon(badge: badge, muted: true, size: badgeSize),
                            Positioned(
                              right: -10,
                              bottom: -10,
                              child: IgnorePointer(
                                child: Container(
                                  width: plusBadgeOuter,
                                  height: plusBadgeOuter,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD8D8DC),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(38),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    border: Border.all(color: Colors.white.withAlpha(230), width: 2),
                                  ),
                                  child: Text(
                                    '+',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: plusFontSize,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                      color: const Color(0xFF1C1C22),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        S.of(context).memoryBadgeTitle(badge),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: memoryBadgeGridTitleStyle(context, badge, muted: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
