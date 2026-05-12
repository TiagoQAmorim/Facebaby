import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../../i18n/app_i18n.dart';
import '../../models/memory_badge.dart';
import 'memory_badges_catalog.dart';
import '../../theme/app_theme.dart';
import '../../utils/memory_moment_localizations.dart';
import '../../utils/portal_layout.dart';
import '../../widgets/memories/cached_memory_photo.dart';
import '../../widgets/memories/memory_badge_icon.dart';

/// Detalhe público da “Foto da Semana” — alinhado ao visual da [MemoryDetailPage],
/// só com campos seguros (sem peso, notas privadas, etc.).
class PublicWeeklyMemoryDetailPage extends StatelessWidget {
  final String photoUrl;
  final String badgeTitle;
  /// Id estável da badge no catálogo (`MemoryBadgesCatalog`) — vem de `winner_badge_id` no Firestore.
  final String? badgeId;
  final String? babyDisplayName;
  final String? babyAgeLabel;
  final String? publicDescription;
  final DateTime memoryDate;

  static const _purpleCardBg = Color(0xFFF3EEFF);
  static const _purpleTitle = Color(0xFF7B5FB8);
  static const _screenBg = Color(0xFFF5F3FA);

  const PublicWeeklyMemoryDetailPage({
    super.key,
    required this.photoUrl,
    required this.badgeTitle,
    this.badgeId,
    this.babyDisplayName,
    this.babyAgeLabel,
    this.publicDescription,
    required this.memoryDate,
  });

  MemoryBadge? _resolveBadge() {
    final id = badgeId?.trim();
    if (id == null || id.isEmpty) return null;
    return MemoryBadgesCatalog.findBadgeById(id);
  }

  String _title(S s, MemoryBadge? badge) {
    if (badge != null) return s.memoryBadgeTitle(badge);
    final raw = badgeTitle.trim();
    return raw.isEmpty ? s.weeklyPhotoPublicDetailAppBar : raw;
  }

  void _openPhotoFullscreen(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      useSafeArea: false,
      barrierColor: Colors.black,
      builder: (ctx) {
        final pad = MediaQuery.paddingOf(ctx);
        final sz = MediaQuery.sizeOf(ctx);
        return Material(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PhotoView(
                imageProvider: memoryPhotoNetworkImageProvider(url),
                minScale: PhotoViewComputedScale.contained * 0.85,
                maxScale: PhotoViewComputedScale.covered * 4,
                initialScale: PhotoViewComputedScale.contained,
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                loadingBuilder: (c, event) => const Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
                filterQuality: FilterQuality.medium,
                customSize: sz,
              ),
              Positioned(
                top: pad.top + 8,
                right: 12,
                child: IconButton(
                  style: IconButton.styleFrom(backgroundColor: Colors.black.withAlpha(140)),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final badge = _resolveBadge();
    final titleText = _title(s, badge);
    final desc = publicDescription?.trim();
    final name = (babyDisplayName ?? '').trim();
    final age = (babyAgeLabel ?? '').trim();
    final showInfoCard = name.isNotEmpty || age.isNotEmpty;

    return Scaffold(
      backgroundColor: _screenBg,
      appBar: AppBar(
        backgroundColor: _screenBg,
        elevation: 0,
        title: const SizedBox.shrink(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (badge != null)
                      MemoryBadgeIcon(
                        badge: badge,
                        muted: false,
                        size: 42,
                        shape: MemoryBadgeIconShape.original,
                      )
                    else
                      _FallbackBadgeTile(fallbackTitle: badgeTitle),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleText,
                            style: TextStyle(
                              fontSize: portalSp(context, 22),
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatMemoryMomentDateTime(context, memoryDate),
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: portalSp(context, 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, c) {
                    final textStyle = TextStyle(
                      color: AppTheme.textPrimary.withAlpha(200),
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      fontSize: portalSp(context, 16),
                    );
                    final veryNarrow = c.maxWidth < 340;
                    final side = veryNarrow ? (c.maxWidth * 0.42).clamp(140.0, 190.0) : (c.maxWidth * 0.40).clamp(180.0, 300.0);
                    const radius = 22.0;

                    Widget photoSquare() {
                      return GestureDetector(
                        onTap: () => _openPhotoFullscreen(context, photoUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(radius),
                          child: SizedBox(
                            width: side,
                            height: side,
                            child: CachedMemoryPhoto(
                              imageUrl: photoUrl,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              filterQuality: FilterQuality.medium,
                              placeholder: (c, u) {
                                return Container(
                                  color: AppTheme.softPurple.withAlpha(80),
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(strokeWidth: 2),
                                );
                              },
                              errorWidget: (_, __, ___) => Container(
                                color: AppTheme.softPurple.withAlpha(80),
                                alignment: Alignment.center,
                                child: Icon(Icons.broken_image_outlined, size: 48, color: AppTheme.textMuted),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    if (desc == null || desc.isEmpty) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          photoSquare(),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                s.memoryNoDescription,
                                style: textStyle.copyWith(color: AppTheme.textMuted),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    final remainingW = (c.maxWidth - side - 18).clamp(90.0, 10000.0);
                    if (remainingW < 120) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(alignment: Alignment.centerLeft, child: photoSquare()),
                          const SizedBox(height: 14),
                          Text(desc, style: textStyle),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        photoSquare(),
                        const SizedBox(width: 18),
                        Expanded(child: Text(desc, style: textStyle)),
                      ],
                    );
                  },
                ),
                if (showInfoCard) ...[
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 11),
                    decoration: BoxDecoration(
                      color: _purpleCardBg,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.memoryMomentInfoTitle,
                          style: TextStyle(
                            color: _purpleTitle,
                            fontWeight: FontWeight.w900,
                            fontSize: portalSp(context, 14),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (name.isNotEmpty)
                              Expanded(
                                child: _PublicMomentChip(
                                  bg: const Color(0xFFFFE9F5),
                                  iconBg: const Color(0xFFFFD0EA),
                                  icon: Icons.child_care_rounded,
                                  iconColor: AppTheme.primaryPink,
                                  label: s.commonName,
                                  value: name,
                                ),
                              ),
                            if (name.isNotEmpty && age.isNotEmpty) const SizedBox(width: 6),
                            if (age.isNotEmpty)
                              Expanded(
                                child: _PublicMomentChip(
                                  bg: const Color(0xFFEDE8FF),
                                  iconBg: const Color(0xFFD9CCFF),
                                  icon: Icons.calendar_month_rounded,
                                  iconColor: AppTheme.primaryPurple,
                                  label: s.memoryStatAgeLabel,
                                  value: age,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackBadgeTile extends StatelessWidget {
  const _FallbackBadgeTile({required this.fallbackTitle});

  final String fallbackTitle;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: fallbackTitle.trim().isEmpty ? '' : fallbackTitle.trim(),
      child: Container(
        width: MemoryBadgeIcon.circularLayoutExtent(42),
        height: MemoryBadgeIcon.circularLayoutExtent(42),
        decoration: BoxDecoration(
          color: AppTheme.softPurple.withAlpha(200),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withAlpha(200)),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.photo_camera_rounded, color: AppTheme.primaryPurple.withAlpha(230), size: 28),
      ),
    );
  }
}

/// Réplica estreita de [_MomentStatChip] na página privada — só nome / idade públicos.
class _PublicMomentChip extends StatelessWidget {
  final Color bg;
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  static const double _nominalChipWidth = 78;

  const _PublicMomentChip({
    required this.bg,
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final raw = ((c.maxWidth - 8) / _nominalChipWidth).clamp(0.52, 1.15);
        final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(0.85, 1.5);
        final s = (raw / textScale).clamp(0.48, 1.12);
        final padH = (3 * s).clamp(2.0, 6.0);
        final padV = (5 * s).clamp(3.0, 9.0);
        final iconD = (30 * s).clamp(21.0, 34.0);
        final iconIx = (16 * s).clamp(12.0, 19.0);
        final gapIco = (4 * s).clamp(2.0, 8.0);
        final gapLbl = (2 * s).clamp(1.0, 4.0);
        final fsLabel = portalSp(context, 9 * s.clamp(0.65, 1.08));
        final fsValue = portalSp(context, 10.5 * s.clamp(0.65, 1.06));
        final labelStyle = TextStyle(
          fontSize: fsLabel.clamp(6.5, 11),
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
          height: 1.05,
        );
        final valueStyle = TextStyle(
          fontSize: fsValue.clamp(7.5, 13),
          fontWeight: FontWeight.w900,
          color: AppTheme.textPrimary,
          height: 1.1,
        );
        final r = BorderRadius.circular((11 * s).clamp(9.0, 16));
        return Container(
          constraints: BoxConstraints(minWidth: c.maxWidth, maxWidth: c.maxWidth),
          padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
          decoration: BoxDecoration(color: bg, borderRadius: r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconD,
                height: iconD,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, size: iconIx, color: iconColor),
              ),
              SizedBox(height: gapIco),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
              SizedBox(height: gapLbl),
              Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: valueStyle,
              ),
            ],
          ),
        );
      },
    );
  }
}
