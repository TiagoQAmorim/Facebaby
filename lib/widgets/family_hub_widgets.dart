import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../models/daily_summary.dart';
import '../theme/app_theme.dart';
import '../utils/family_zodiac_art.dart';
import '../utils/zodiac_element.dart';
import '../utils/zodiac_keys.dart';

const Color _kHubPink = Color(0xFFE84D7A);
const Color _kHubInk = Color(0xFF2B2233);
const Color _kHubMuted = Color(0xFF7A7080);
const int _kFamilyBannerAlpha = 142;
const int _kFamilyBannerBorderAlpha = 92;

String familyHubFmtHm(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// Seletor organico Mamae, bebe e papai.
class FamilyRelationshipSelector extends StatelessWidget {
  const FamilyRelationshipSelector({
    super.key,
    required this.motherLabel,
    required this.motherAvatar,
    required this.motherSelected,
    required this.onMother,
    required this.babyLabel,
    required this.babyAvatar,
    required this.babySelected,
    required this.onBaby,
    this.fatherLabel,
    this.fatherAvatar,
    this.fatherSelected = false,
    this.onFather,
  });

  final String motherLabel;
  final Widget motherAvatar;
  final bool motherSelected;
  final VoidCallback onMother;

  final String babyLabel;
  final Widget babyAvatar;
  final bool babySelected;
  final VoidCallback onBaby;

  final String? fatherLabel;
  final Widget? fatherAvatar;
  final bool fatherSelected;
  final VoidCallback? onFather;

  @override
  Widget build(BuildContext context) {
    final hasFather = fatherAvatar != null && onFather != null;

    Widget adultNode({
      required Widget avatar,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      final outerSize = selected ? 112.0 : 86.0;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: selected ? 1 : 0.9,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: outerSize,
            height: outerSize,
            padding: EdgeInsets.all(selected ? 4 : 3),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(selected ? 252 : 235),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? _kHubPink.withAlpha(210) : Colors.white,
                width: selected ? 3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(selected ? 38 : 14),
                  blurRadius: selected ? 22 : 9,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: FittedBox(fit: BoxFit.cover, child: avatar),
          ),
        ),
      );
    }

    Widget babyNode() {
      final outerSize = babySelected ? 132.0 : 108.0;
      return InkWell(
        onTap: onBaby,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 148,
          height: 144,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: babySelected ? 0 : 10,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: outerSize,
                  height: outerSize,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(248),
                    border: Border.all(
                      color: babySelected ? _kHubPink : Colors.white,
                      width: babySelected ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kHubPink.withAlpha(babySelected ? 90 : 38),
                        blurRadius: babySelected ? 26 : 12,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FittedBox(fit: BoxFit.cover, child: babyAvatar),
                ),
              ),
              Positioned(
                top: babySelected ? -4 : 7,
                left: babySelected ? 18 : 25,
                child: Image.asset(
                  'assets/weekly_photo/crown.png',
                  width: 28,
                  height: 28,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.workspace_premium_rounded,
                    size: 28,
                    color: Colors.amber.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 148,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 20,
            right: 20,
            bottom: 70,
            height: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    _kHubPink.withAlpha(0),
                    _kHubPink.withAlpha(110),
                    _kHubPink.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 2,
            bottom: 8,
            child: adultNode(
              avatar: motherAvatar,
              label: motherLabel,
              selected: motherSelected,
              onTap: onMother,
            ),
          ),
          Positioned(
            right: 2,
            bottom: 8,
            child: hasFather
                ? adultNode(
                    avatar: fatherAvatar!,
                    label: fatherLabel ?? '',
                    selected: fatherSelected,
                    onTap: onFather!,
                  )
                : const SizedBox(width: 94, height: 94),
          ),
          Center(child: babyNode()),
        ],
      ),
    );
  }
}

class FamilyHubAvatarRibbon extends FamilyRelationshipSelector {
  const FamilyHubAvatarRibbon({
    super.key,
    required super.motherLabel,
    required super.motherAvatar,
    required super.motherSelected,
    required super.onMother,
    required super.babyLabel,
    required super.babyAvatar,
    required super.babySelected,
    required super.onBaby,
    super.fatherLabel,
    super.fatherAvatar,
    super.fatherSelected,
    super.onFather,
  });
}

/// Cartao rosa principal do bebe.
class FamilyHubBabyHeroCard extends StatelessWidget {
  const FamilyHubBabyHeroCard({
    super.key,
    required this.s,
    required this.babyName,
    required this.ageLabel,
    required this.birthDateStr,
    required this.weightStr,
    required this.heightStr,
    required this.signDisplayName,
    required this.showZodiac,
    required this.babyAvatar,
    this.signId,
    this.heightEstimateTitle,
    this.heightEstimateBody,
    this.heightEstimateDescription,
    this.heightEstimateAsset,
    this.onTap,
  });

  final S s;
  final String babyName;
  final String ageLabel;
  final String birthDateStr;
  final String weightStr;
  final String heightStr;
  final String signDisplayName;
  final bool showZodiac;
  final Widget babyAvatar;
  final ZodiacId? signId;
  final String? heightEstimateTitle;
  final String? heightEstimateBody;
  final String? heightEstimateDescription;
  final String? heightEstimateAsset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final element = signId == null ? null : zodiacElementFor(signId!);
    final elementName = element == null ? '?' : s.zodiacElementLabel(element);

    Widget zodiacArt(double size) {
      if (signId == null) {
        return Icon(
          Icons.auto_awesome_rounded,
          size: size,
          color: AppTheme.primaryPurple.withAlpha(210),
        );
      }
      return Image.asset(
        familyZodiacIconAsset(signId!),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.auto_awesome_rounded,
          size: size,
          color: AppTheme.primaryPurple,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 380;
        final hasHeightEstimate =
            heightEstimateTitle != null && heightEstimateBody != null;
        final cardHeight = hasHeightEstimate
            ? (compact ? 248.0 : 266.0)
            : (compact ? 165.0 : 180.0);
        final avatarSize =
            showZodiac ? (compact ? 76.0 : 82.0) : (compact ? 92.0 : 100.0);
        const nameSize = 23.0;
        const itemSize = 14.0;

        Widget infoLine(IconData icon, String text) {
          return Row(
            children: [
              Icon(icon, size: 17, color: _kHubPink.withAlpha(220)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: itemSize,
                    fontWeight: FontWeight.w700,
                    color: _kHubInk,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          );
        }

        Widget photo() {
          return SizedBox(
            width: avatarSize + 10,
            height: avatarSize + 16,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: _kHubPink.withAlpha(170), width: 2),
                    ),
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(28),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FittedBox(fit: BoxFit.cover, child: babyAvatar),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 2,
                  child: Image.asset(
                    'assets/weekly_photo/crown.png',
                    width: compact ? 24 : 26,
                    height: compact ? 24 : 26,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.amber.shade700,
                      size: compact ? 24 : 26,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget signBlock() {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: FittedBox(child: zodiacArt(30)),
              ),
              const SizedBox(height: 6),
              Text(
                signDisplayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _kHubPink,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                elementName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kHubMuted.withAlpha(245),
                  height: 1.05,
                ),
              ),
            ],
          );
        }

        return SizedBox(
          height: cardHeight,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(26),
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  color: Colors.white.withAlpha(_kFamilyBannerAlpha),
                  border: Border.all(
                      color: Colors.white.withAlpha(_kFamilyBannerBorderAlpha)),
                  boxShadow: [
                    BoxShadow(
                      color: _kHubPink.withAlpha(35),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 36,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  babyName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: nameSize,
                                    fontWeight: FontWeight.w900,
                                    color: _kHubPink,
                                    height: 1.05,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  ageLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _kHubInk,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                infoLine(
                                    Icons.calendar_today_rounded, birthDateStr),
                                const SizedBox(height: 5),
                                infoLine(
                                    Icons.monitor_weight_outlined, weightStr),
                                const SizedBox(height: 5),
                                infoLine(Icons.straighten_rounded, heightStr),
                              ],
                            ),
                          ),
                          if (showZodiac) ...[
                            Expanded(flex: 34, child: Center(child: photo())),
                            Expanded(flex: 30, child: signBlock()),
                          ] else
                            Expanded(
                              flex: 58,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Transform.translate(
                                  offset: const Offset(8, 0),
                                  child: photo(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (hasHeightEstimate) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (heightEstimateAsset != null)
                            Transform.translate(
                              offset: const Offset(0, 18),
                              child: SizedBox(
                                width: compact ? 108 : 128,
                                height: compact ? 132 : 152,
                                child: Image.asset(
                                  heightEstimateAsset!,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.height_rounded,
                                    size: compact ? 72 : 84,
                                    color: _kHubPink.withAlpha(230),
                                  ),
                                ),
                              ),
                            )
                          else
                            Icon(Icons.height_rounded,
                                size: 68, color: _kHubPink.withAlpha(230)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  heightEstimateTitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: _kHubInk,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  heightEstimateBody!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: _kHubPink,
                                    height: 1.12,
                                  ),
                                ),
                                if (heightEstimateDescription != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    heightEstimateDescription!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: _kHubMuted.withAlpha(245),
                                      height: 1.12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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

class FamilyHubAdultHeroCard extends StatelessWidget {
  const FamilyHubAdultHeroCard({
    super.key,
    required this.s,
    required this.roleLabel,
    required this.name,
    required this.ageLabel,
    required this.birthDateStr,
    required this.heightStr,
    required this.signDisplayName,
    required this.showZodiac,
    required this.avatar,
    required this.accent,
    this.signId,
    this.onTap,
  });

  final S s;
  final String roleLabel;
  final String name;
  final String ageLabel;
  final String birthDateStr;
  final String heightStr;
  final String signDisplayName;
  final bool showZodiac;
  final Widget avatar;
  final Color accent;
  final ZodiacId? signId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget zodiacArt() {
      if (signId == null) {
        return Icon(Icons.auto_awesome_rounded, color: accent, size: 30);
      }
      return Image.asset(
        familyZodiacIconAsset(signId!),
        width: 30,
        height: 30,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.auto_awesome_rounded, color: accent, size: 30),
      );
    }

    Widget infoLine(IconData icon, String value) {
      return Row(
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _kHubInk,
                height: 1.08,
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: 150,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withAlpha(_kFamilyBannerAlpha),
              border: Border.all(
                  color: Colors.white.withAlpha(_kFamilyBannerBorderAlpha)),
              boxShadow: [
                BoxShadow(
                  color: accent.withAlpha(22),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withAlpha(34),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: FittedBox(fit: BoxFit.cover, child: avatar),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 21,
                            height: 1.02,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          showZodiac
                              ? '$signDisplayName · $roleLabel'
                              : roleLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _kHubInk,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 7),
                        infoLine(Icons.calendar_month_rounded, ageLabel),
                        const SizedBox(height: 4),
                        infoLine(Icons.cake_outlined, birthDateStr),
                        const SizedBox(height: 4),
                        infoLine(Icons.straighten_rounded, heightStr),
                      ],
                    ),
                  ),
                  if (showZodiac) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 54,
                      height: 54,
                      child: FittedBox(child: zodiacArt()),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FamilyHubContentCards extends StatelessWidget {
  const FamilyHubContentCards({
    super.key,
    required this.s,
    required this.horoscopeTitle,
    required this.horoscopeBody,
    required this.bibleTitle,
    required this.bibleBody,
    this.bibleReference,
    required this.showHoroscope,
    required this.showChristian,
    required this.contentUnlocked,
    this.signId,
  });

  final S s;
  final String horoscopeTitle;
  final String horoscopeBody;
  final String bibleTitle;
  final String bibleBody;
  final String? bibleReference;
  final bool showHoroscope;
  final bool showChristian;
  final bool contentUnlocked;
  final ZodiacId? signId;

  @override
  Widget build(BuildContext context) {
    if (!showHoroscope && !showChristian) return const SizedBox.shrink();

    final reference = _cleanReference(bibleReference);
    final verse = _cleanVerseBody(bibleBody, reference);
    final lockedBody = s.familyPremiumFeatureLockedBody;

    Widget emotionalCard({
      required IconData icon,
      required Color accent,
      required String title,
      required String body,
      String? assetIcon,
      String? reference,
    }) {
      final cleanBody =
          body.trim().isEmpty ? s.familyEntertainmentNote : body.trim();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(_kFamilyBannerAlpha),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: Colors.white.withAlpha(_kFamilyBannerBorderAlpha)),
          boxShadow: [
            BoxShadow(
              color: accent.withAlpha(16),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: assetIcon == null
                      ? Icon(icon, size: 48, color: accent)
                      : Image.asset(
                          assetIcon,
                          width: 52,
                          height: 52,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            icon,
                            size: 48,
                            color: accent,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _kHubInk,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              cleanBody,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.32,
                fontWeight: FontWeight.w500,
                color: _kHubInk.withAlpha(224),
              ),
            ),
            if (reference != null && reference.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                reference.trim(),
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: accent.withAlpha(225),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 430 && showHoroscope && showChristian;
        final cards = <Widget>[
          if (showChristian)
            emotionalCard(
              icon: Icons.menu_book_rounded,
              accent: _kHubPink,
              assetIcon: familyChristianCrossAsset,
              title: bibleTitle,
              body: contentUnlocked ? verse : lockedBody,
              reference: contentUnlocked ? reference : null,
            ),
          if (showHoroscope)
            emotionalCard(
              icon: Icons.auto_awesome_rounded,
              accent: AppTheme.primaryPurple,
              assetIcon: signId == null ? null : familyZodiacIconAsset(signId!),
              title: horoscopeTitle,
              body:
                  contentUnlocked ? horoscopeBody : s.familyPremiumZodiacLocked,
            ),
        ];

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              cards[i],
            ],
          ],
        );
      },
    );
  }

  static String? _cleanReference(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    var value = trimmed;
    const emDash = '\u2014';
    while (value.startsWith('-') || value.startsWith(emDash)) {
      value = value.substring(1).trimLeft();
    }
    return value;
  }

  static String _cleanVerseBody(String rawBody, String? reference) {
    var body = rawBody.trim();
    final ref = reference?.trim();
    if (ref == null || ref.isEmpty) return body;

    const emDash = '\u2014';
    if (body.endsWith(ref)) {
      body = body.substring(0, body.length - ref.length).trimRight();
      while (body.endsWith('-') || body.endsWith(emDash)) {
        body = body.substring(0, body.length - 1).trimRight();
      }
    }
    return body;
  }
}

class FamilyHubDailySummaryStrip extends StatelessWidget {
  const FamilyHubDailySummaryStrip({
    super.key,
    required this.s,
    required this.summary,
    this.dayLabel,
    this.isToday = true,
    this.onPickDay,
    this.onToday,
    this.lastFeed,
    this.lastDiaper,
    this.lastSleep,
  });

  final S s;
  final DailySummary summary;
  final String? dayLabel;
  final bool isToday;
  final VoidCallback? onPickDay;
  final VoidCallback? onToday;
  final DateTime? lastFeed;
  final DateTime? lastDiaper;
  final DateTime? lastSleep;

  @override
  Widget build(BuildContext context) {
    String feedSub() {
      if (lastFeed == null) return '—';
      return s.familySummaryLastAt(familyHubFmtHm(lastFeed!));
    }

    String diaperSub() {
      if (lastDiaper == null) return '—';
      return s.familySummaryLastAt(familyHubFmtHm(lastDiaper!));
    }

    String sleepSub() {
      if (lastSleep == null) return '—';
      return s.familySummaryLastSleepAt(familyHubFmtHm(lastSleep!));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/weekly_photo/crown.png',
              width: 22,
              height: 22,
              errorBuilder: (_, __, ___) => Icon(Icons.star_rounded,
                  size: 22, color: Colors.amber.shade600),
            ),
            const SizedBox(width: 6),
            Text(
              s.familyDailySummaryTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _kHubInk,
              ),
            ),
            if (dayLabel != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dayLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _kHubMuted.withAlpha(230),
                  ),
                ),
              ),
            ] else
              const Spacer(),
            if (!isToday && onToday != null)
              TextButton(
                onPressed: onToday,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(s.homeTodayLabel),
              ),
            IconButton(
              tooltip: s.homeSummaryPickDayTooltip,
              onPressed: onPickDay,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              icon: Icon(
                Icons.calendar_month_rounded,
                size: 21,
                color: AppTheme.primaryPurple.withAlpha(220),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, _) {
            const gap = 10.0;
            Widget card({
              required Color color,
              required Color softBg,
              required IconData icon,
              required String title,
              required String line1,
              required String line2,
            }) {
              return _miniSummaryCard(
                color: color,
                softBg: softBg,
                icon: icon,
                title: title,
                line1: line1,
                line2: line2,
              );
            }

            final cards = <Widget>[
              card(
                color: AppTheme.primaryPink,
                softBg: Colors.white.withAlpha(_kFamilyBannerAlpha),
                icon: Icons.local_drink_rounded,
                title: s.familySummaryFeeding,
                line1: s.familySummaryFeedingsToday(summary.feedings),
                line2: feedSub(),
              ),
              card(
                color: const Color(0xFF2EB872),
                softBg: Colors.white.withAlpha(_kFamilyBannerAlpha),
                icon: Icons.baby_changing_station_rounded,
                title: s.familySummaryDiapers,
                line1: s.familySummaryDiaperChangesCount(summary.diapers),
                line2: diaperSub(),
              ),
              card(
                color: AppTheme.primary,
                softBg: Colors.white.withAlpha(_kFamilyBannerAlpha),
                icon: Icons.nightlight_round,
                title: s.familySummarySleep,
                line1: summary.sleep.replaceAll(' ', ''),
                line2: sleepSub(),
              ),
              card(
                color: AppTheme.yellow,
                softBg: Colors.white.withAlpha(_kFamilyBannerAlpha),
                icon: Icons.monitor_weight_outlined,
                title: s.familySummaryWeight,
                line1: summary.weight.replaceAll(' ', ''),
                line2: s.familySummaryWeightDayLine,
              ),
            ];

            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: gap),
                    Expanded(child: cards[1]),
                  ],
                ),
                const SizedBox(height: gap),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: gap),
                    Expanded(child: cards[3]),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  static Widget _miniSummaryCard({
    required Color color,
    required Color softBg,
    required IconData icon,
    required String title,
    required String line1,
    required String line2,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104, maxHeight: 112),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: softBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: Colors.white.withAlpha(_kFamilyBannerBorderAlpha)),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 7),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color.withAlpha(255),
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            line1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _kHubInk,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            line2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _kHubMuted.withAlpha(235),
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class FamilyHubPremiumBanner extends StatelessWidget {
  const FamilyHubPremiumBanner({
    super.key,
    required this.s,
    this.onPremiumTap,
  });

  final S s;
  final VoidCallback? onPremiumTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onPremiumTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withAlpha(_kFamilyBannerAlpha),
            border: Border.all(
                color: Colors.white.withAlpha(_kFamilyBannerBorderAlpha)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withAlpha(40),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, c) {
                final compact = c.maxWidth < 360;
                final icon = Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/weekly_photo/crown.png',
                    width: 32,
                    height: 32,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.amber.shade700,
                    ),
                  ),
                );
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.familyPremiumBannerTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryPurple,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      s.familyPremiumBannerBody,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kHubMuted.withAlpha(245),
                        height: 1.25,
                      ),
                    ),
                  ],
                );
                final button = FilledButton(
                  onPressed: onPremiumTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    s.familyPremiumViewPlans,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          icon,
                          const SizedBox(width: 12),
                          Expanded(child: copy),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerRight, child: button),
                    ],
                  );
                }

                return Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: copy),
                    const SizedBox(width: 12),
                    button,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
