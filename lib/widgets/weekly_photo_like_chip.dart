import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../services/firebase/weekly_photo_like_service.dart';
import '../theme/app_theme.dart';
import '../utils/portal_layout.dart';
import '../utils/portal_time_of_day.dart';

Future<void> _handleWeeklyPhotoLikeTap(BuildContext context, String id) async {
  final trimmed = id.trim();
  if (trimmed.isEmpty) return;
  final s = S.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final ok = await WeeklyPhotoLikeService.instance.toggleLike(trimmed);
    if (!context.mounted) return;
    if (!ok) {
      messenger?.showSnackBar(
        SnackBar(content: Text(s.weeklyPhotoLikeNeedSignIn)),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    messenger?.showSnackBar(
      SnackBar(content: Text('${s.commonCouldNotSave} $e')),
    );
  }
}

/// Curtidas na Foto da Semana — chip compacto ou barra com botão «Curtir».
class WeeklyPhotoLikeChip extends StatelessWidget {
  const WeeklyPhotoLikeChip({
    super.key,
    required this.publicMemoryId,
    this.readOnly = false,
    this.compact = false,
    this.lightOnPhoto = false,
    this.prominent = false,
  });

  final String publicMemoryId;
  final bool readOnly;
  final bool compact;
  final bool lightOnPhoto;

  /// Barra na Home: botão «Curtir» + contagem única à direita.
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final id = publicMemoryId.trim();
    if (id.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<WeeklyPhotoLikeState>(
      stream: WeeklyPhotoLikeService.watch(id),
      builder: (context, snap) {
        final state =
            snap.data ?? const WeeklyPhotoLikeState(count: 0, likedByMe: false);
        final s = S.of(context);
        final countLabel = s.weeklyPhotoLikesCount(state.count);

        if (prominent) {
          return _ProminentLikeBar(
            state: state,
            readOnly: readOnly,
            countLabel: countLabel,
            onToggle: () => _handleWeeklyPhotoLikeTap(context, id),
            likeLabel: s.weeklyPhotoLikeButton,
            likedLabel: s.weeklyPhotoLikedButton,
          );
        }

        final label = countLabel;
        final iconSize = compact ? 20.0 : 22.0;
        final fs = portalSp(context, compact ? 12.5 : 13.5);

        final heartColor = state.likedByMe
            ? (lightOnPhoto ? const Color(0xFFFF6B9D) : const Color(0xFFE91E63))
            : (lightOnPhoto
                ? Colors.white.withAlpha(235)
                : const Color(0xFF74717F));

        final textColor = lightOnPhoto ? Colors.white : const Color(0xFF1F1F2E);

        final content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.likedByMe
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: iconSize,
              color: heartColor,
            ),
            SizedBox(width: compact ? 4 : 6),
            Text(
              label,
              style: TextStyle(
                fontSize: fs,
                fontWeight: FontWeight.w800,
                color: textColor,
                height: 1.1,
                shadows: lightOnPhoto
                    ? const [
                        Shadow(
                          blurRadius: 8,
                          color: Color(0x88000000),
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        );

        if (readOnly) {
          return Material(
            color: lightOnPhoto
                ? Colors.black.withAlpha(72)
                : Colors.white.withAlpha(230),
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 6 : 8,
              ),
              child: content,
            ),
          );
        }

        return Material(
          color: lightOnPhoto
              ? Colors.black.withAlpha(72)
              : Colors.white.withAlpha(235),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: () => _handleWeeklyPhotoLikeTap(context, id),
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 6 : 8,
              ),
              child: content,
            ),
          ),
        );
      },
    );
  }
}

class _ProminentLikeBar extends StatelessWidget {
  const _ProminentLikeBar({
    required this.state,
    required this.readOnly,
    required this.countLabel,
    required this.onToggle,
    required this.likeLabel,
    required this.likedLabel,
  });

  final WeeklyPhotoLikeState state;
  final bool readOnly;
  final String countLabel;
  final VoidCallback onToggle;
  final String likeLabel;
  final String likedLabel;

  @override
  Widget build(BuildContext context) {
    final night = PortalTimeOfDay.isNight(DateTime.now());
    final nightTextColor =
        night ? PortalTimeOfDay.nightOutlinedTextColor : null;
    final nightShadows = night ? PortalTimeOfDay.nightTextOutlineShadows : null;
    return Row(
      children: [
        if (readOnly)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 22,
                color: AppTheme.primaryPink.withAlpha(230),
              ),
              const SizedBox(width: 8),
              Text(
                countLabel,
                style: TextStyle(
                  fontSize: portalSp(context, 14),
                  fontWeight: FontWeight.w800,
                  color: nightTextColor ?? AppTheme.textPrimary,
                  shadows: nightShadows,
                ),
              ),
            ],
          )
        else if (state.likedByMe)
          FilledButton.tonalIcon(
            onPressed: onToggle,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryPink.withAlpha(36),
              foregroundColor: AppTheme.primaryPink,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.favorite_rounded, size: 20),
            label: Text(
              likedLabel,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          )
        else
          FilledButton.icon(
            onPressed: onToggle,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.ctaPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            icon: const Icon(Icons.favorite_border_rounded, size: 20),
            label: Text(
              likeLabel,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        if (!readOnly) ...[
          const Spacer(),
          Text(
            countLabel,
            style: TextStyle(
              fontSize: portalSp(context, 14),
              fontWeight: FontWeight.w800,
              color: nightTextColor ?? AppTheme.textSecondary,
              shadows: nightShadows,
            ),
          ),
        ],
      ],
    );
  }
}
