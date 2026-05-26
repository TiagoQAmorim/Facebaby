import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
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
    this.vibrant = true,
    this.tagline,
    this.wrapContent = false,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback? onTap;
  final bool compact;
  final Color accent;
  final bool vibrant;
  final String? tagline;
  /// Família / telas com texto longo: mais linhas e menos corte.
  final bool wrapContent;

  static LinearGradient _vibrantGradient(bool night, Color accent) {
    if (night) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(AppTheme.primaryPink, accent, 0.2)!,
          Color.lerp(AppTheme.primaryPurple, accent, 0.35)!,
          Color.lerp(const Color(0xFF8E24AA), accent, 0.25)!,
        ],
        stops: const [0.0, 0.5, 1.0],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(AppTheme.primaryPink, accent, 0.15)!,
        Color.lerp(AppTheme.primaryPurple, accent, 0.35)!,
        Color.lerp(const Color(0xFF5B4B86), accent, 0.2)!,
      ],
      stops: const [0.0, 0.52, 1.0],
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? 18 : 28);
    final night = PortalTimeOfDay.isNight(DateTime.now());
    final muted = vibrant ? null : _mutedStyle(night, accent);
    final s = S.of(context);

    final bgGradient =
        vibrant ? _vibrantGradient(night, accent) : muted!.bgGradient;
    final borderColor = vibrant
        ? Colors.white.withAlpha(night ? 72 : 118)
        : muted!.borderColor;
    final titleColor = vibrant ? Colors.white : muted!.titleColor;
    final subtitleColor =
        vibrant ? Colors.white.withAlpha(228) : muted!.subtitleColor;
    final taglineColor = vibrant ? const Color(0xFFFFF3C4) : subtitleColor;
    final titleShadows = vibrant
        ? const [
            Shadow(
              blurRadius: 10,
              color: Color(0x66000000),
              offset: Offset(0, 2),
            ),
          ]
        : (night && !vibrant ? PortalTimeOfDay.nightTextOutlineShadows : null);
    final ctaColor = vibrant
        ? const Color(0xFFFFF3C4)
        : (night ? PortalTimeOfDay.nightOutlinedTextColor : accent);

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
            border: Border.all(color: borderColor, width: vibrant ? 1.6 : 1.4),
            boxShadow: [
              BoxShadow(
                color: (vibrant ? AppTheme.primaryPink : Colors.black)
                    .withAlpha(vibrant ? (night ? 70 : 95) : (night ? 48 : 32)),
                blurRadius: vibrant ? (compact ? 16 : 22) : (compact ? 12 : 18),
                offset: Offset(0, vibrant ? 8 : (compact ? 5 : 8)),
              ),
              if (vibrant)
                BoxShadow(
                  color: accent.withAlpha(night ? 80 : 110),
                  blurRadius: compact ? 18 : 26,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 18,
              compact ? 10 : 14,
              compact ? 10 : 14,
              compact ? 10 : (wrapContent ? 16 : 14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PremiumCrownBadge(
                  compact: compact,
                  accent: accent,
                  night: night,
                  vibrant: vibrant,
                ),
                SizedBox(width: compact ? 10 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: wrapContent ? 2 : (compact ? 2 : 1),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: portalSp(context, compact ? 14 : 18),
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                          height: 1.1,
                          shadows: titleShadows,
                        ),
                      ),
                      if (vibrant && !compact) ...[
                        SizedBox(height: compact ? 6 : 8),
                        _PaymentBadgesRow(
                          compact: compact,
                          lifetimeLabel: s.plusPopularBadge,
                          noMonthlyLabel: s.plusEarlyAdopterOffer,
                        ),
                      ],
                      if (tagline != null && tagline!.trim().isNotEmpty) ...[
                        SizedBox(height: compact ? 5 : 7),
                        Text(
                          tagline!.trim(),
                          maxLines: wrapContent ? 3 : (compact ? 3 : 2),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: portalSp(context, compact ? 12.5 : 13.5),
                            fontWeight: FontWeight.w800,
                            color: taglineColor,
                            height: 1.28,
                            shadows: titleShadows,
                          ),
                        ),
                      ],
                      SizedBox(height: compact ? 4 : 7),
                      Text(
                        subtitle,
                        maxLines: wrapContent ? 5 : (compact ? 4 : 3),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: portalSp(context, compact ? 11.5 : 13),
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                          height: 1.28,
                          shadows: vibrant ? null : titleShadows,
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 9),
                        Text(
                          ctaLabel,
                          style: TextStyle(
                            fontSize: portalSp(context, 12.5),
                            fontWeight: FontWeight.w900,
                            color: ctaColor,
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
                  color: (vibrant
                          ? Colors.white
                          : (night
                              ? PortalTimeOfDay.nightOutlinedTextColor
                              : accent))
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

class _MutedCardStyle {
  const _MutedCardStyle({
    required this.bgGradient,
    required this.borderColor,
    required this.titleColor,
    required this.subtitleColor,
  });

  final LinearGradient bgGradient;
  final Color borderColor;
  final Color titleColor;
  final Color subtitleColor;
}

_MutedCardStyle _mutedStyle(bool night, Color accent) {
  return _MutedCardStyle(
    bgGradient: night
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(AppTheme.primaryPink, accent, 0.15)!,
              Color.lerp(AppTheme.primaryPurple, accent, 0.4)!,
            ],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(AppTheme.primaryPink, accent, 0.12)!.withAlpha(235),
              Color.lerp(AppTheme.primaryPurple, accent, 0.28)!.withAlpha(245),
            ],
          ),
    borderColor: night
        ? Colors.white.withAlpha(72)
        : Color.lerp(AppTheme.primaryPink, accent, 0.45)!,
    titleColor: night ? Colors.white.withAlpha(242) : const Color(0xFF5A1B4E),
    subtitleColor: night
        ? Colors.white.withAlpha(210)
        : Color.lerp(AppTheme.primaryPurple, accent, 0.5)!,
  );
}

class _PaymentBadgesRow extends StatelessWidget {
  const _PaymentBadgesRow({
    required this.compact,
    required this.lifetimeLabel,
    required this.noMonthlyLabel,
  });

  final bool compact;
  final String lifetimeLabel;
  final String noMonthlyLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: compact ? 6 : 8,
      runSpacing: 6,
      children: [
        _BadgePill(
          icon: Icons.payments_rounded,
          label: lifetimeLabel,
          compact: compact,
        ),
        _BadgePill(
          icon: Icons.event_busy_rounded,
          label: noMonthlyLabel,
          compact: compact,
        ),
      ],
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({
    required this.icon,
    required this.label,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(200)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 13 : 14,
            color: const Color(0xFFB71C5C),
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 132 : 168),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: TextStyle(
                fontSize: compact ? 10 : 10.5,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF6A1B5C),
                height: 1.12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCrownBadge extends StatelessWidget {
  const _PremiumCrownBadge({
    required this.compact,
    required this.accent,
    required this.night,
    required this.vibrant,
  });

  final bool compact;
  final Color accent;
  final bool night;
  final bool vibrant;

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
              color: vibrant
                  ? Colors.white.withAlpha(42)
                  : (night
                      ? Colors.white.withAlpha(28)
                      : const Color(0xFFC8C3D0).withAlpha(220)),
              border: Border.all(
                color: vibrant
                    ? Colors.white.withAlpha(160)
                    : accent.withAlpha(night ? 70 : 95),
                width: 1.1,
              ),
              borderRadius: BorderRadius.circular(compact ? 17 : 28),
              boxShadow: vibrant
                  ? [
                      BoxShadow(
                        color: Colors.white.withAlpha(80),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: SizedBox(width: size * 0.86, height: size * 0.86),
          ),
          Positioned(
            left: compact ? 2 : 4,
            top: compact ? 2 : 7,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: compact ? 13 : 18,
              color: vibrant
                  ? const Color(0xFFFFF3C4)
                  : accent.withAlpha(175),
            ),
          ),
          Opacity(
            opacity: vibrant ? 1.0 : (night ? 0.88 : 0.78),
            child: vibrant
                ? Image.asset(
                    'assets/weekly_photo/crown.png',
                    width: crownSize,
                    height: crownSize,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.workspace_premium_rounded,
                      size: crownSize,
                      color: const Color(0xFFFFF3C4),
                    ),
                  )
                : ColorFiltered(
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
          if (!vibrant)
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
