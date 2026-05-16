import 'package:flutter/material.dart';

import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../services/development_leaps_service.dart';
import '../theme/app_theme.dart';
import '../utils/portal_layout.dart';

/// Banner da semana de salto de desenvolvimento (nuvem + faixa etária).
class DevelopmentLeapBannerCard extends StatelessWidget {
  const DevelopmentLeapBannerCard({super.key, required this.onOpen});

  final VoidCallback onOpen;

  String _babyName(S s) {
    final n =
        (CurrentBabyController.instance.currentBabyRow?['name'] as String?)
            ?.trim();
    return (n == null || n.isEmpty) ? s.baby : n;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final name = _babyName(s);
    final birthRaw =
        CurrentBabyController.instance.currentBabyRow?['birth_date'] as String?;
    final birth = DateTime.tryParse((birthRaw ?? '').trim());
    if (birth == null) return const SizedBox.shrink();

    final leap = DevelopmentLeapsService.current(birthDate: birth);
    if (leap == null) return const SizedBox.shrink();

    final bk = leap.bannerKey;
    final rangeLbl = s.developmentLeapBannerRange(bk);
    final titleLbl = s.developmentLeapBannerTitle(bk);
    final lead =
        s.developmentLeapBannerLead(bk).replaceAll('{baby_name}', name);
    final emoLine = s.developmentLeapBannerEmotion(bk);
    const pink = AppTheme.primaryPink;
    const ink = AppTheme.textPrimary;

    return Material(
      color: Color.lerp(Colors.white, pink, 0.06),
      elevation: 1.5,
      shadowColor: pink.withAlpha(30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: pink.withAlpha(55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DevelopmentLeapFloatingCloud(accent: pink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titleLbl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: portalSp(context, 16),
                              color: ink,
                              height: 1.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: pink.withAlpha(26),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            rangeLbl,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              color: pink.withAlpha(230),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lead,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: ink.withAlpha(220),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '💜 $emoLine',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: ink.withAlpha(215),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s.devLeapsSeeDetails,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: pink.withAlpha(240),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: pink.withAlpha(240),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevelopmentLeapFloatingCloud extends StatefulWidget {
  const _DevelopmentLeapFloatingCloud({required this.accent});

  final Color accent;

  @override
  State<_DevelopmentLeapFloatingCloud> createState() =>
      _DevelopmentLeapFloatingCloudState();
}

class _DevelopmentLeapFloatingCloudState extends State<_DevelopmentLeapFloatingCloud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  late final Animation<double> _dy = Tween<double>(begin: -0.02, end: 0.02)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pink = widget.accent;
    return AnimatedBuilder(
      animation: _dy,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, _dy.value * 60),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: pink.withAlpha(22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pink.withAlpha(60)),
            ),
            child: Icon(Icons.cloud_rounded, color: pink.withAlpha(235), size: 24),
          ),
        );
      },
    );
  }
}
