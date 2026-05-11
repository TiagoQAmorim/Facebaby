import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../pages/memories/public_weekly_memory_detail_page.dart';
import '../services/firebase/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/memory_moment_localizations.dart';
import '../utils/portal_layout.dart';
import '../utils/weekly_photo_schedule.dart';

/// Secção “Foto da Semana” no final da Home (só quando `spotlight_current` está no período de exibição).
class WeeklyPhotoHomeSection extends StatelessWidget {
  const WeeklyPhotoHomeSection({super.key});

  bool _inDisplayWindow(Map<String, dynamic>? d, DateTime now) {
    if (d == null) return false;
    final status = d['status'] as String?;
    if (status != null && status != 'active') return false;
    final drawAt = d['draw_at'];
    final until = d['display_until'];
    if (drawAt is! Timestamp || until is! Timestamp) return false;
    return WeeklyPhotoSchedule.isWithinSpotlightDisplay(
      now: now,
      drawAt: drawAt.toDate(),
      displayUntil: until.toDate(),
    );
  }

  void _openDetail(
    BuildContext context, {
    required String photoUrl,
    required String badgeTitle,
    String? babyName,
    String? babyAge,
    String? desc,
    required DateTime memoryDate,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicWeeklyMemoryDetailPage(
          photoUrl: photoUrl,
          badgeTitle: badgeTitle,
          babyDisplayName: babyName,
          babyAgeLabel: babyAge,
          publicDescription: desc,
          memoryDate: memoryDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.instance.weeklyPhotoSpotlightSnapshots(),
      builder: (context, snap) {
        final d = snap.data?.data();
        final now = DateTime.now();
        if (!_inDisplayWindow(d, now)) return const SizedBox.shrink();

        final photoUrl = (d!['winner_photo_url'] as String?)?.trim();
        final badgeTitle = (d['winner_badge_title'] as String?)?.trim();
        if (photoUrl == null || photoUrl.isEmpty || badgeTitle == null || badgeTitle.isEmpty) {
          return const SizedBox.shrink();
        }

        final babyName = (d['winner_baby_display_name'] as String?)?.trim();
        final babyAge = (d['winner_baby_age_label'] as String?)?.trim();
        final desc = (d['winner_public_description'] as String?)?.trim();
        final memoryDateIso = (d['winner_memory_date'] as String?)?.trim();
        final memoryDate = DateTime.tryParse(memoryDateIso ?? '') ?? now;

        final s = S.of(context);
        final babyLabel = (babyName != null && babyName.isNotEmpty) ? babyName : s.weeklyPhotoBabyFallback;
        final spotlightSex = (d['winner_baby_sex'] as String?)?.trim();
        final sectionTitle = s.weeklyPhotoSectionTitleForBabySex(spotlightSex);

        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sectionTitle,
                style: TextStyle(
                  fontSize: portalSp(context, 18),
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.weeklyPhotoSectionSubtitle,
                style: TextStyle(
                  fontSize: portalSp(context, 13),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                child: Card(
                  elevation: 0,
                  color: AppTheme.softPurple.withAlpha(100),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openDetail(
                      context,
                      photoUrl: photoUrl,
                      badgeTitle: badgeTitle,
                      babyName: babyName,
                      babyAge: babyAge,
                      desc: desc,
                      memoryDate: memoryDate,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.softPurple.withAlpha(90),
                              alignment: Alignment.center,
                              child: Icon(Icons.photo_outlined, size: 44, color: AppTheme.textMuted),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                badgeTitle,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                babyLabel,
                                style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatMemoryMomentDateTime(context, memoryDate),
                                style: TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton(
                                  onPressed: () => _openDetail(
                                    context,
                                    photoUrl: photoUrl,
                                    badgeTitle: badgeTitle,
                                    babyName: babyName,
                                    babyAge: babyAge,
                                    desc: desc,
                                    memoryDate: memoryDate,
                                  ),
                                  child: Text(s.weeklyPhotoViewMemory),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                s.weeklyPhotoDisclaimerShort,
                style: TextStyle(fontSize: portalSp(context, 11.5), color: AppTheme.textMuted, height: 1.35),
              ),
            ],
          ),
        );
      },
    );
  }
}
