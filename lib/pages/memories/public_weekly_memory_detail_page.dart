import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../theme/app_theme.dart';
import '../../utils/memory_moment_localizations.dart';
import '../../utils/portal_layout.dart';

/// Visualização só com dados seguros para outras mães (sem peso, observações privadas, etc.).
class PublicWeeklyMemoryDetailPage extends StatelessWidget {
  final String photoUrl;
  final String badgeTitle;
  final String? babyDisplayName;
  final String? babyAgeLabel;
  final String? publicDescription;
  final DateTime memoryDate;

  const PublicWeeklyMemoryDetailPage({
    super.key,
    required this.photoUrl,
    required this.badgeTitle,
    this.babyDisplayName,
    this.babyAgeLabel,
    this.publicDescription,
    required this.memoryDate,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final desc = publicDescription?.trim();
    return Scaffold(
      appBar: AppBar(title: Text(s.weeklyPhotoPublicDetailAppBar)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      loadingBuilder: (c, w, ev) {
                        if (ev == null) return w;
                        return Container(
                          color: AppTheme.softPurple.withAlpha(80),
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.softPurple.withAlpha(80),
                        alignment: Alignment.center,
                        child: Icon(Icons.broken_image_outlined, size: 48, color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  badgeTitle,
                  style: TextStyle(
                    fontSize: portalSp(context, 22),
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatMemoryMomentDateTime(context, memoryDate),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: portalSp(context, 14),
                    color: AppTheme.textSecondary,
                  ),
                ),
                if ((babyDisplayName ?? '').trim().isNotEmpty || (babyAgeLabel ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if ((babyDisplayName ?? '').trim().isNotEmpty)
                        Chip(
                          label: Text(babyDisplayName!.trim()),
                          backgroundColor: AppTheme.softPink.withAlpha(180),
                          side: BorderSide.none,
                        ),
                      if ((babyAgeLabel ?? '').trim().isNotEmpty)
                        Chip(
                          label: Text(babyAgeLabel!.trim()),
                          backgroundColor: AppTheme.softPurple.withAlpha(120),
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                ],
                if (desc != null && desc.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: portalSp(context, 15),
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary.withAlpha(220),
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
