import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/portal_layout.dart';
import '../utils/portal_time_of_day.dart';

class PremiumLockedContentCard extends StatelessWidget {
  const PremiumLockedContentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    this.onTap,
    this.compact = false,
    this.accent = AppTheme.primaryPurple,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback? onTap;
  final bool compact;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? 18 : 28);
    final night = PortalTimeOfDay.isNight(DateTime.now());
    final bgGradient = night
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2E384C),
              Color(0xFF3A455C),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFD4D0DC),
              Color(0xFFE4E0EA),
            ],
          );
    final borderColor = night
        ? Colors.white.withAlpha(52)
        : Color.lerp(const Color(0xFF9E97AB), accent, 0.35)!;
    final titleColor = night
        ? PortalTimeOfDay.nightOutlinedTextColor.withAlpha(242)
        : const Color(0xFF4F4B59);
    final subtitleColor = night
        ? PortalTimeOfDay.nightTextColor.withAlpha(200)
        : AppTheme.textSecondary;
    final titleShadows =
        night ? PortalTimeOfDay.nightTextOutlineShadows : null;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: bgGradient,
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(night ? 48 : 32),
                blurRadius: compact ? 12 : 18,
                offset: Offset(0, compact ? 5 : 8),
              ),
              BoxShadow(
                color: accent.withAlpha(night ? 55 : 72),
                blurRadius: compact ? 14 : 22,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 18,
              compact ? 10 : 14,
              compact ? 10 : 14,
              compact ? 10 : 14,
            ),
            child: Row(
              children: [
                _PremiumCrownBadge(
                  compact: compact,
                  accent: accent,
                  night: night,
                ),
                SizedBox(width: compact ? 10 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: portalSp(context, compact ? 14 : 18),
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                          height: 1.1,
                          shadows: titleShadows,
                        ),
                      ),
                      SizedBox(height: compact ? 4 : 7),
                      Text(
                        subtitle,
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: portalSp(context, compact ? 12 : 13.5),
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                          height: 1.28,
                          shadows: titleShadows,
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 9),
                        Text(
                          ctaLabel,
                          style: TextStyle(
                            fontSize: portalSp(context, 12.5),
                            fontWeight: FontWeight.w900,
                            color: night
                                ? PortalTimeOfDay.nightOutlinedTextColor
                                : accent,
                            height: 1,
                            shadows: titleShadows,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: compact ? 6 : 10),
                Icon(
                  Icons.chevron_right_rounded,
                  size: compact ? 26 : 34,
                  color: (night
                          ? PortalTimeOfDay.nightOutlinedTextColor
                          : accent)
                      .withAlpha(230),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumCrownBadge extends StatelessWidget {
  const _PremiumCrownBadge({
    required this.compact,
    required this.accent,
    required this.night,
  });

  final bool compact;
  final Color accent;
  final bool night;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 52.0 : 82.0;
    final crownSize = compact ? 34.0 : 56.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: night
                  ? Colors.white.withAlpha(28)
                  : const Color(0xFFC8C3D0).withAlpha(220),
              border: Border.all(
                color: accent.withAlpha(night ? 70 : 95),
                width: 1.1,
              ),
              borderRadius: BorderRadius.circular(compact ? 17 : 28),
            ),
            child: SizedBox(width: size * 0.86, height: size * 0.86),
          ),
          Positioned(
            left: compact ? 2 : 4,
            top: compact ? 2 : 7,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: compact ? 13 : 18,
              color: accent.withAlpha(175),
            ),
          ),
          Opacity(
            opacity: night ? 0.88 : 0.78,
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(<double>[
                0.45, 0.35, 0.2, 0, 35,
                0.35, 0.35, 0.3, 0, 35,
                0.25, 0.3, 0.45, 0, 40,
                0, 0, 0, 1, 0,
              ]),
              child: Image.asset(
                'assets/weekly_photo/crown.png',
                width: crownSize,
                height: crownSize,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.workspace_premium_rounded,
                  size: crownSize,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          Positioned(
            right: compact ? 3 : 6,
            bottom: compact ? 5 : 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withAlpha(120),
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: compact ? 7 : 10,
                height: compact ? 7 : 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
