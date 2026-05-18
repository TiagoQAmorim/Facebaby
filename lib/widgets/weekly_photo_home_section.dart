import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../pages/memories/memory_badges_catalog.dart';
import '../pages/memories/public_weekly_memory_detail_page.dart';
import '../services/firebase/firestore_service.dart';
import '../services/firebase/weekly_photo_spotlight_http.dart';
import '../theme/app_theme.dart';
import '../utils/memory_moment_localizations.dart';
import '../utils/portal_layout.dart';
import '../utils/portal_time_of_day.dart';
import '../utils/weekly_photo_spotlight_visibility.dart';
import '../widgets/memories/cached_memory_photo.dart';
import '../widgets/memories/memory_badge_icon.dart';
import '../widgets/weekly_photo_crown_icon.dart';
import '../widgets/weekly_photo_like_chip.dart';

const int _kHomeBannerAlpha = 142;
const int _kHomeBannerBorderAlpha = 92;

/// Secção “Foto da Semana” no final da Home (segunda a segunda; `spotlight_current` ativo no período).
///
/// Stream Firestore + pedido HTTP a [WeeklyPhotoSpotlightHttp] (vários URLs) em paralelo e nova
/// tentativa aos 2s se ainda não houver dados mostráveis — contorna regras e deploy Gen2 (`*.run.app`).
class WeeklyPhotoHomeSection extends StatefulWidget {
  const WeeklyPhotoHomeSection({super.key});

  @override
  State<WeeklyPhotoHomeSection> createState() => _WeeklyPhotoHomeSectionState();
}

class _WeeklyPhotoHomeSectionState extends State<WeeklyPhotoHomeSection> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _streamSub;
  Map<String, dynamic>? _streamData;

  Map<String, dynamic>? _httpData;
  bool _httpFetchInFlight = false;
  Timer? _httpStartTimer;

  void _startHttpSpotlightFetch() {
    if (_httpFetchInFlight) return;
    _httpFetchInFlight = true;
    unawaited(
      WeeklyPhotoSpotlightHttp.fetch().then((data) {
        if (!mounted) return;
        setState(() {
          _httpFetchInFlight = false;
          if (data != null) _httpData = data;
        });
      }).catchError((Object e, StackTrace st) {
        debugPrint('WeeklyPhotoHomeSection: HTTP spotlight failed: $e\n$st');
        if (mounted) setState(() => _httpFetchInFlight = false);
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    if (FirebaseAuth.instance.currentUser != null) {
      _streamSub = FirestoreService.instance
          .weeklyPhotoSpotlightSnapshots()
          .listen((snap) {
        if (!mounted) return;
        setState(() {
          _streamData = snap.data();
        });
      }, onError: (Object e, StackTrace st) {
        debugPrint('WeeklyPhotoHomeSection: stream error: $e');
        _startHttpSpotlightFetch();
      });
    }
    // HTTP em paralelo (não esperar 2s): Gen2 / regras podem falhar o stream; vários hosts em [WeeklyPhotoSpotlightHttp].
    _startHttpSpotlightFetch();
    _httpStartTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final now = DateTime.now();
      if (WeeklyPhotoSpotlightVisibility.shouldShowForBanner(
              _streamData, now) ||
          WeeklyPhotoSpotlightVisibility.shouldShowForBanner(_httpData, now)) {
        return;
      }
      _startHttpSpotlightFetch();
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _httpStartTimer?.cancel();
    super.dispose();
  }

  void _openDetail(
    BuildContext context, {
    required String publicMemoryId,
    required String photoUrl,
    required String badgeTitle,
    String? badgeId,
    String? babyName,
    String? babyAge,
    String? desc,
    required DateTime memoryDate,
    String? winnerUserId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicWeeklyMemoryDetailPage(
          publicMemoryId: publicMemoryId,
          photoUrl: photoUrl,
          badgeTitle: badgeTitle,
          badgeId: badgeId,
          babyDisplayName: babyName,
          babyAgeLabel: babyAge,
          publicDescription: desc,
          memoryDate: memoryDate,
          winnerUserId: winnerUserId,
        ),
      ),
    );
  }

  String? _winnerUserId(Map<String, dynamic> data) {
    final raw = data['winner_user_id'] ?? data['winnerUserId'];
    final id = raw == null ? '' : '$raw'.trim();
    return id.isEmpty ? null : id;
  }

  Color _heroTitleColor(String? spotlightSex) {
    final sx = (spotlightSex ?? '').trim().toUpperCase();
    if (sx == 'M') {
      return const Color(0xFF2E7BD6);
    }
    return const Color(0xFFD63384);
  }

  String? _normalisedSpotlightBabySex(Map<String, dynamic> data) {
    for (final value in [
      data['winner_baby_sex'],
      data['winnerBabySex'],
      data['babySex'],
      data['baby_sex'],
      data['sex'],
      data['gender'],
    ]) {
      final sx = value == null ? '' : '$value'.trim().toUpperCase();
      if (sx == 'M' ||
          sx == 'MALE' ||
          sx == 'BOY' ||
          sx == 'MASCULINO' ||
          sx == 'MENINO') {
        return 'M';
      }
      if (sx == 'F' ||
          sx == 'FEMALE' ||
          sx == 'GIRL' ||
          sx == 'FEMININO' ||
          sx == 'MENINA') {
        return 'F';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null)
      return const SizedBox.shrink();

    final now = DateTime.now();
    // Preferir Firestore (real-time). Cair para HTTP se este não trouxer dados utilizáveis.
    Map<String, dynamic>? d = _streamData;
    if (!WeeklyPhotoSpotlightVisibility.shouldShowForBanner(d, now)) {
      d = _httpData;
    }
    if (!WeeklyPhotoSpotlightVisibility.shouldShowForBanner(d, now)) {
      return const SizedBox.shrink();
    }

    final photoUrl = (d!['winner_photo_url'] as String?)?.trim() ??
        (d['winnerPhotoUrl'] as String?)?.trim();
    final badgeTitle = (d['winner_badge_title'] as String?)?.trim() ??
        (d['winnerBadgeTitle'] as String?)?.trim();
    if (photoUrl == null ||
        photoUrl.isEmpty ||
        badgeTitle == null ||
        badgeTitle.isEmpty) {
      return const SizedBox.shrink();
    }

    final badgeId = (d['winner_badge_id'] as String?)?.trim() ??
        (d['winnerBadgeId'] as String?)?.trim();
    final publicMemoryId = (d['winner_public_memory_id'] as String?)?.trim() ??
        (d['winnerPublicMemoryId'] as String?)?.trim() ??
        '';
    final winnerUserId = _winnerUserId(d);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isWinnerMom = winnerUserId != null &&
        currentUid != null &&
        winnerUserId == currentUid;

    final babyName = (d['winner_baby_display_name'] as String?)?.trim();
    final rawBabyAge = (d['winner_baby_age_label'] as String?)?.trim() ??
        (d['winnerBabyAgeLabel'] as String?)?.trim();
    final desc = (d['winner_public_description'] as String?)?.trim();
    final memoryDateIso = (d['winner_memory_date'] as String?)?.trim();
    final memoryDate = DateTime.tryParse(memoryDateIso ?? '') ?? now;

    final s = S.of(context);
    final babyAge = s.localizedAgeLabelFromStored(rawBabyAge);
    final spotlightSex = _normalisedSpotlightBabySex(d);
    final heroTitle = s.weeklyPhotoHomeHeroTitle(spotlightSex);
    final night = PortalTimeOfDay.isNight(DateTime.now());
    final nightTextColor =
        night ? PortalTimeOfDay.nightOutlinedTextColor : null;
    final nightShadows = night ? PortalTimeOfDay.nightTextOutlineShadows : null;
    final heroColor = nightTextColor ?? _heroTitleColor(spotlightSex);

    final catalogBadge = (badgeId != null && badgeId.isNotEmpty)
        ? MemoryBadgesCatalog.findBadgeById(badgeId)
        : null;
    final displayBadgeTitle =
        catalogBadge != null ? s.memoryBadgeTitle(catalogBadge) : badgeTitle;

    // Linha “bebê · idade” só com dados reais (sem placeholder “Bebê”).
    final hasName = babyName != null && babyName.isNotEmpty;
    final hasAge = babyAge.isNotEmpty;
    String? babyLine;
    if (hasName && hasAge) {
      babyLine = '$babyName · $babyAge';
    } else if (hasName) {
      babyLine = babyName;
    } else if (hasAge) {
      babyLine = babyAge;
    }
    final hasDesc = desc != null && desc.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              WeeklyPhotoCrownIcon(size: portalSp(context, 24)),
              SizedBox(width: portalSp(context, 10)),
              Expanded(
                child: Text(
                  heroTitle,
                  style: TextStyle(
                    fontSize: portalSp(context, 19),
                    fontWeight: FontWeight.w900,
                    color: heroColor,
                    shadows: nightShadows,
                    height: 1.15,
                    letterSpacing: 0.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: Card(
              elevation: 0,
              color: Colors.white.withAlpha(_kHomeBannerAlpha),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                  color: Colors.white.withAlpha(_kHomeBannerBorderAlpha),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openDetail(
                  context,
                  publicMemoryId: publicMemoryId,
                  photoUrl: photoUrl,
                  badgeTitle: badgeTitle,
                  badgeId:
                      (badgeId != null && badgeId.isNotEmpty) ? badgeId : null,
                  babyName: babyName,
                  babyAge: babyAge,
                  desc: desc,
                  memoryDate: memoryDate,
                  winnerUserId: winnerUserId,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedMemoryPhoto(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withAlpha(35),
                                    Colors.black.withAlpha(168),
                                  ],
                                  stops: const [0.0, 0.45, 1.0],
                                ),
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 28, 12, 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (catalogBadge != null)
                                      MemoryBadgeIcon(
                                        badge: catalogBadge,
                                        muted: false,
                                        size: 30,
                                        shape: MemoryBadgeIconShape.circle,
                                      )
                                    else
                                      Container(
                                        width: MemoryBadgeIcon
                                            .circularLayoutExtent(30),
                                        height: MemoryBadgeIcon
                                            .circularLayoutExtent(30),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(230),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(40),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.workspace_premium_rounded,
                                          size: 26,
                                          color: AppTheme.primaryPink
                                              .withAlpha(240),
                                        ),
                                      ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        displayBadgeTitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: portalSp(context, 15),
                                          height: 1.2,
                                          shadows: const [
                                            Shadow(
                                              blurRadius: 10,
                                              color: Color(0x88000000),
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (babyLine != null ||
                        hasDesc ||
                        publicMemoryId.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (publicMemoryId.isNotEmpty) ...[
                              if (isWinnerMom)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    s.weeklyPhotoLikesWinnerHint,
                                    style: TextStyle(
                                      fontSize: portalSp(context, 12.5),
                                      fontWeight: FontWeight.w700,
                                      color: nightTextColor ??
                                          AppTheme.textSecondary,
                                      shadows: nightShadows,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              WeeklyPhotoLikeChip(
                                publicMemoryId: publicMemoryId,
                                prominent: true,
                              ),
                              const SizedBox(height: 10),
                            ],
                            if (babyLine != null)
                              Text(
                                babyLine,
                                style: TextStyle(
                                  color: nightTextColor ?? AppTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: portalSp(context, 14),
                                  shadows: nightShadows,
                                ),
                              ),
                            if (hasDesc) ...[
                              if (babyLine != null) const SizedBox(height: 6),
                              Text(
                                desc,
                                style: TextStyle(
                                  fontSize: portalSp(context, 13),
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              formatMemoryMomentDateTime(context, memoryDate),
                              style: TextStyle(
                                fontSize: portalSp(context, 11.5),
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w600,
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
            style: TextStyle(
                fontSize: portalSp(context, 11.5),
                color: AppTheme.textMuted,
                height: 1.35),
          ),
        ],
      ),
    );
  }
}
