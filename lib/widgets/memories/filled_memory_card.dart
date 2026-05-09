import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../i18n/app_i18n.dart';
import '../../models/baby_memory.dart';
import '../../models/memory_badge.dart';
import '../../theme/app_theme.dart';
import '../../utils/photo_b64.dart';
import '../../utils/portal_layout.dart';
import 'memory_badge_grid_title.dart';
import 'memory_badge_icon.dart';

/// Célula preenchida: pré-visualização redonda (foto ou badge) + texto abaixo.
class FilledMemoryCard extends StatelessWidget {
  final MemoryBadge badge;
  final BabyMemory memory;
  final VoidCallback onTap;

  const FilledMemoryCard({
    super.key,
    required this.badge,
    required this.memory,
    required this.onTap,
  });

  String _fmt(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y • $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final bytes = decodePhotoB64(memory.photoB64);
    final url = (memory.photoUrl ?? '').trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final ch = constraints.maxHeight;
        // O [GridView] define altura fixa por célula; o círculo + textos precisam caber sem overflow.
        // Antes usávamos `min(cw, ch)` para o diâmetro, mas `ch` inclui o espaço dos textos — isso estourava ~12px.
        const verticalPadding = 8.0 * 2; // Ink padding top/bottom
        const gapAfterCircle = 8.0;
        final titleFs = portalSp(context, 11.8);
        final dateFs = portalSp(context, 9.5);
        // Título pode ocupar até 2 linhas; data é 1 linha.
        final textBlockH = (titleFs * 2.0 * 1.12) + (dateFs * 1.05) + gapAfterCircle;

        double dForCorner(double dGuess) {
          final corner = (dGuess * 0.26).clamp(18.0, 30.0);
          return math.max(0.0, (corner + 6.0) - 10.0);
        }

        double solveD() {
          var dGuess = (math.min(cw, ch.isFinite ? (ch - verticalPadding - textBlockH) : (cw * 0.92)) * 0.92).clamp(52.0, 118.0);
          if (!ch.isFinite) return dGuess;

          // 2 iterações bastam: o overflow do canto depende de `d` e reduz o espaço útil do círculo.
          for (var i = 0; i < 2; i++) {
            final overflow = dForCorner(dGuess);
            final avail = (ch - verticalPadding - textBlockH - overflow).clamp(0.0, double.infinity);
            final next = (math.min(cw, avail) * 0.92).clamp(52.0, 118.0);
            if ((next - dGuess).abs() < 0.25) return next;
            dGuess = next;
          }
          return dGuess;
        }

        final d = solveD();
        final badgeSize = (d * 0.45).clamp(22.0, 48.0);
        /// Badge no canto da foto (não muted — mantém cor).
        final cornerBadgeSize = (d * 0.26).clamp(18.0, 30.0);
        final hasPhoto = bytes != null || url.isNotEmpty;

        Widget roundContent;
        if (hasPhoto) {
          roundContent = SizedBox(
            width: d,
            height: d,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: d,
                    height: d,
                    child: bytes != null
                        ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
                        : Image.network(url, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  // Deixa o badge mais "para fora" para cobrir menos a foto.
                  right: -10,
                  bottom: -10,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: MemoryBadgeIcon(
                      badge: badge,
                      muted: false,
                      size: cornerBadgeSize,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          roundContent = ClipOval(
            child: Container(
              width: d,
              height: d,
              color: MemoryBadgeIcon.mutedDiskBackground,
              alignment: Alignment.center,
              child: MemoryBadgeIcon(badge: badge, muted: true, size: badgeSize),
            ),
          );
        }

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
                    Color.lerp(Colors.white, badge.defaultColor, hasPhoto ? 0.12 : 0.08)!,
                    Color.lerp(Colors.white, badge.defaultColor, 0.035)!,
                  ],
                ),
                border: Border.all(color: badge.defaultColor.withAlpha(hasPhoto ? 52 : 38)),
                boxShadow: [
                  BoxShadow(
                    color: badge.defaultColor.withAlpha(hasPhoto ? 40 : 26),
                    blurRadius: hasPhoto ? 14 : 8,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    roundContent,
                    const SizedBox(height: 8),
                    Text(
                      S.of(context).memoryBadgeTitle(badge),
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: memoryBadgeGridTitleStyle(context, badge, muted: !hasPhoto),
                    ),
                    Text(
                      _fmt(memory.memoryDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: portalSp(context, 9.5),
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
