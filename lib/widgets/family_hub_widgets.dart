import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../models/daily_summary.dart';
import '../theme/app_theme.dart';
import '../utils/family_zodiac_art.dart';
import '../utils/zodiac_element.dart';
import '../utils/zodiac_keys.dart';

const Color _kHubPink = Color(0xFFE84D7A);
const Color _kHubPinkSoft = Color(0xFFFFE5EE);
const Color _kHubInk = Color(0xFF2B2233);
const Color _kHubMuted = Color(0xFF7A7080);

String familyHubFmtHm(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// Faixa Mamãe · ♥ · Bebê (grande) · ♥ · Papai.
class FamilyHubAvatarRibbon extends StatelessWidget {
  const FamilyHubAvatarRibbon({
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

  static const _heart =
      Icon(Icons.favorite_rounded, size: 16, color: Color(0xFFFF7AA8));

  @override
  Widget build(BuildContext context) {
    final hasFather = fatherAvatar != null && onFather != null;

    Widget personNode({
      required Widget avatar,
      required String label,
      required bool selected,
      required VoidCallback onTap,
      required bool isBaby,
    }) {
      final baseScale = isBaby ? 0.88 : 0.54;
      final selectedScale = isBaby ? 1.16 : 1.5;
      return AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        scale: selected ? selectedScale : 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    if (isBaby)
                      Positioned(
                        top: -8,
                        child: Image.asset(
                          'assets/weekly_photo/crown.png',
                          width: selected ? 30 : 24,
                          height: selected ? 30 : 24,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.workspace_premium_rounded,
                            size: selected ? 26 : 22,
                            color: Colors.amber.shade600,
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.only(top: isBaby ? 10 : 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: EdgeInsets.all(selected ? 4 : 2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          gradient: isBaby
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFFFA8CC),
                                    Color(0xFFFF6FA8),
                                  ],
                                )
                              : null,
                          border: Border.all(
                            color: selected ? _kHubPink : Colors.white,
                            width: selected ? 3 : 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (selected ? _kHubPink : Colors.black)
                                  .withAlpha(selected ? 70 : 20),
                              blurRadius: selected ? 18 : 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Transform.scale(
                          scale: baseScale,
                          alignment: Alignment.center,
                          child: avatar,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 84),
                  child: Text(
                    label.trim().isEmpty ? '—' : label.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: selected ? 12 : 11,
                      fontWeight: FontWeight.w900,
                      color: selected ? _kHubPink : _kHubMuted,
                      height: 1.05,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    List<Widget> nodes(double w) {
      final left = (w * 0.06).clamp(0.0, 42.0);
      final center = ((w - 104) / 2).clamp(74.0, w - 178);
      final right = (w - 108 - left).clamp(center + 58, w - 92);
      final items = <({bool selected, Widget child})>[
        (
          selected: motherSelected,
          child: Positioned(
            left: left,
            top: 18,
            width: 104,
            child: personNode(
              avatar: motherAvatar,
              label: motherLabel,
              selected: motherSelected,
              onTap: onMother,
              isBaby: false,
            ),
          )
        ),
        (
          selected: babySelected,
          child: Positioned(
            left: center,
            top: 2,
            width: 104,
            child: personNode(
              avatar: babyAvatar,
              label: babyLabel,
              selected: babySelected,
              onTap: onBaby,
              isBaby: true,
            ),
          )
        ),
        if (hasFather)
          (
            selected: fatherSelected,
            child: Positioned(
              left: right,
              top: 18,
              width: 104,
              child: personNode(
                avatar: fatherAvatar!,
                label: fatherLabel ?? '',
                selected: fatherSelected,
                onTap: onFather!,
                isBaby: false,
              ),
            )
          ),
      ];
      items.sort((a, b) => a.selected == b.selected ? 0 : (a.selected ? 1 : -1));
      return [for (final item in items) item.child];
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 140,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 16,
                right: 16,
                top: 32,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(138),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _kHubPink.withAlpha(70)),
                  ),
                ),
              ),
              Positioned(
                left: 52,
                right: 52,
                top: 58,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: LinearGradient(
                      colors: [
                        _kHubPink.withAlpha(40),
                        _kHubPink.withAlpha(150),
                        _kHubPink.withAlpha(40),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: w * 0.31,
                top: 48,
                child: _heart,
              ),
              Positioned(
                right: w * 0.31,
                top: 48,
                child: _heart,
              ),
              ...nodes(w),
            ],
          ),
        );
      },
    );
  }
}

/// Cartão rosa principal do bebê (mock «Família»).
class FamilyHubBabyHeroCard extends StatelessWidget {
  const FamilyHubBabyHeroCard({
    super.key,
    required this.s,
    required this.babyName,
    required this.ageLabel,
    required this.birthDateStr,
    required this.birthTimeStr,
    required this.weightStr,
    required this.heightStr,
    required this.signDisplayName,
    required this.babyAvatar,
    this.signId,
    this.onTap,
  });

  final S s;
  final String babyName;
  final String ageLabel;
  final String birthDateStr;
  final String birthTimeStr;
  final String weightStr;
  final String heightStr;
  final String signDisplayName;
  final Widget babyAvatar;
  final ZodiacId? signId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final element = signId == null ? null : zodiacElementFor(signId!);
    final elementName = element == null ? '—' : s.zodiacElementLabel(element);

    Widget zodiacArt() {
      if (signId == null) {
        return Icon(Icons.auto_awesome_rounded, size: 52, color: AppTheme.primaryPurple.withAlpha(200));
      }
      return Image.asset(
        familyZodiacIconAsset(signId!),
        width: 56,
        height: 56,
        errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome_rounded, size: 52, color: AppTheme.primaryPurple),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF0F5),
                Color(0xFFFFD6E8),
                Color(0xFFFFC4DF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _kHubPink.withAlpha(35),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final compact = c.maxWidth < 355;
                    final photoSize = compact ? 78.0 : 90.0;
                    final sideGap = compact ? 4.0 : 7.0;

                    Widget photo() {
                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomLeft,
                        children: [
                          Positioned(
                            left: -10,
                            top: -12,
                            child: Image.asset(
                              'assets/weekly_photo/crown.png',
                              width: compact ? 38 : 44,
                              height: compact ? 38 : 44,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.workspace_premium_rounded,
                                color: Colors.amber.shade700,
                                size: compact ? 32 : 38,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
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
                            child: ClipOval(
                              child: SizedBox(
                                width: photoSize,
                                height: photoSize,
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: babyAvatar,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: -4,
                            bottom: -2,
                            child: Image.asset(
                              'assets/onboarding/cloud_icon.png',
                              width: compact ? 28 : 32,
                              height: compact ? 28 : 32,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                babyName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
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
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: _kHubInk,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _iconLine(Icons.calendar_today_rounded,
                                  birthDateStr),
                              const SizedBox(height: 3),
                              _iconLine(Icons.schedule_rounded, birthTimeStr),
                              const SizedBox(height: 3),
                              _iconLine(
                                  Icons.monitor_weight_outlined, weightStr),
                              const SizedBox(height: 3),
                              _iconLine(Icons.straighten_rounded, heightStr),
                            ],
                          ),
                        ),
                        SizedBox(width: sideGap),
                        photo(),
                        SizedBox(width: sideGap),
                        SizedBox(
                          width: compact ? 62 : 72,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: compact ? 42 : 48,
                                height: compact ? 42 : 48,
                                child: FittedBox(child: zodiacArt()),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                signDisplayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: _kHubPink,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                s.familyFieldElement,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _kHubMuted.withAlpha(240),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.water_drop_rounded,
                                    size: 14,
                                    color: Colors.blue.shade400,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      elementName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: _kHubInk,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _iconLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _kHubPink.withAlpha(220)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: _kHubInk,
            ),
          ),
        ),
      ],
    );
  }
}

/// Linha branca Nascimento · Hora · Signo · Elemento.
class FamilyHubQuickStatsRow extends StatelessWidget {
  const FamilyHubQuickStatsRow({
    super.key,
    required this.s,
    required this.birthDateStr,
    required this.birthTimeStr,
    required this.signDisplayName,
    required this.elementLabel,
  });

  final S s;
  final String birthDateStr;
  final String birthTimeStr;
  final String signDisplayName;
  final String elementLabel;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(14),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kHubMuted.withAlpha(240),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: _kHubInk,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        cell(s.familyQuickLabelBirth, birthDateStr),
        const SizedBox(width: 8),
        cell(s.familyQuickLabelTime, birthTimeStr),
        const SizedBox(width: 8),
        cell(s.familyFieldSign, signDisplayName),
        const SizedBox(width: 8),
        cell(s.familyFieldElement, elementLabel),
      ],
    );
  }
}

class FamilyHubPremiumGrid extends StatelessWidget {
  const FamilyHubPremiumGrid({
    super.key,
    required this.s,
    required this.horoscopeTitle,
    required this.horoscopeBody,
    required this.bibleTitle,
    required this.bibleBody,
    required this.zodiacUnlocked,
    required this.showHoroscope,
    required this.showChristian,
    this.onPremiumTap,
  });

  final S s;
  final String horoscopeTitle;
  final String horoscopeBody;
  final String bibleTitle;
  final String bibleBody;
  final bool zodiacUnlocked;
  final bool showHoroscope;
  final bool showChristian;
  final VoidCallback? onPremiumTap;

  @override
  Widget build(BuildContext context) {
    if (!showHoroscope && !showChristian) return const SizedBox.shrink();

    Widget card({
      required IconData icon,
      required Color iconBg,
      required String title,
      required String body,
      required bool locked,
      String? assetIcon,
    }) {
      return Expanded(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          elevation: 2,
          shadowColor: Colors.black.withAlpha(22),
          child: InkWell(
            onTap: locked ? onPremiumTap : null,
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: iconBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: assetIcon == null
                                ? Icon(icon, size: 20, color: Colors.white)
                                : Image.asset(
                                    assetIcon,
                                    width: 24,
                                    height: 24,
                                    errorBuilder: (_, __, ___) => Icon(
                                      icon,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: _kHubInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (body.isEmpty)
                        Text(
                          s.familyPremiumFeatureLockedBody,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: _kHubMuted.withAlpha(240),
                          ),
                        )
                      else
                        Text(
                          body,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.38,
                            fontWeight: FontWeight.w600,
                            color: _kHubInk.withAlpha(230),
                          ),
                        ),
                    ],
                  ),
                ),
                if (locked)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        color: Colors.white.withAlpha(175),
                        alignment: Alignment.center,
                        child: Icon(Icons.lock_rounded, color: AppTheme.primaryPurple.withAlpha(200), size: 28),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final horoscopeLocked = showHoroscope && !zodiacUnlocked;
    final bibleLocked = showChristian && !zodiacUnlocked;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHoroscope)
          card(
            icon: Icons.auto_awesome_rounded,
            iconBg: AppTheme.primaryPurple,
            title: horoscopeTitle,
            body: horoscopeLocked ? '' : horoscopeBody,
            locked: horoscopeLocked,
          ),
        if (showHoroscope && showChristian) const SizedBox(width: 10),
        if (showChristian)
          card(
            icon: Icons.menu_book_rounded,
            iconBg: const Color(0xFFFFF3DF),
            assetIcon: familyChristianCrossAsset,
            title: bibleTitle,
            body: bibleLocked ? '' : bibleBody,
            locked: bibleLocked,
          ),
      ],
    );
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
              errorBuilder: (_, __, ___) => Icon(Icons.star_rounded, size: 22, color: Colors.amber.shade600),
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
        const SizedBox(height: 12),
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
                softBg: const Color(0xFFFFF0F5),
                icon: Icons.local_drink_rounded,
                title: s.familySummaryFeeding,
                line1: s.familySummaryFeedingsToday(summary.feedings),
                line2: feedSub(),
              ),
              card(
                color: const Color(0xFF2EB872),
                softBg: const Color(0xFFEEFAF3),
                icon: Icons.baby_changing_station_rounded,
                title: s.familySummaryDiapers,
                line1: s.familySummaryDiaperChangesCount(summary.diapers),
                line2: diaperSub(),
              ),
              card(
                color: AppTheme.primary,
                softBg: const Color(0xFFF1EFFF),
                icon: Icons.nightlight_round,
                title: s.familySummarySleep,
                line1: summary.sleep.replaceAll(' ', ''),
                line2: sleepSub(),
              ),
              card(
                color: AppTheme.yellow,
                softBg: const Color(0xFFFFF8ED),
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
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: softBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(55)),
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
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color.withAlpha(255),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            line1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _kHubInk,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            line2,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kHubMuted.withAlpha(235),
              height: 1.2,
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
            gradient: LinearGradient(
              colors: [
                const Color(0xFFF5ECFF),
                _kHubPinkSoft.withAlpha(240),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withAlpha(40),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/weekly_photo/crown.png',
                    width: 32,
                    height: 32,
                    errorBuilder: (_, __, ___) => Icon(Icons.workspace_premium_rounded, color: Colors.amber.shade700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.familyPremiumBannerTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryPurple,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.familyPremiumBannerBody,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kHubMuted.withAlpha(245),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onPremiumTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    '${s.familyPremiumViewPlans} ›',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
