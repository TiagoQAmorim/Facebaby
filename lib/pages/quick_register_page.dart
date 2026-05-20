import 'package:flutter/material.dart';

import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../theme/app_theme.dart';
import '../utils/portal_night_ui.dart';
import '../utils/portal_page_route.dart';
import '../utils/portal_time_of_day.dart';
import 'diaper_page.dart';
import 'feeding_hub_page.dart';
import 'growth_register_page.dart';
import 'health_hub_page.dart';
import 'reports/reports_hub_page.dart';
import 'sleep_page.dart';

class QuickRegisterPage extends StatefulWidget {
  const QuickRegisterPage({super.key});

  @override
  State<QuickRegisterPage> createState() => _QuickRegisterPageState();
}

class _QuickRegisterPageState extends State<QuickRegisterPage> with AutomaticKeepAliveClientMixin {
  final _currentBaby = CurrentBabyController.instance;

  @override
  void initState() {
    super.initState();
    _currentBaby.addListener(_onBabyChanged);
  }

  @override
  void dispose() {
    _currentBaby.removeListener(_onBabyChanged);
    super.dispose();
  }

  void _onBabyChanged() {
    if (mounted) setState(() {});
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final babyId = _currentBaby.currentBabyId;

    return PortalNightUi.listen((context, night) {
      return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(AppTheme.pageHPadding, 24, AppTheme.pageHPadding, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.quickRecordsTitle,
            style: PortalNightUi.titleStyle(night, fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            s.quickRecordsSubtitle,
            style: PortalNightUi.bodyStyle(night, fontSize: 14).copyWith(
              fontWeight: FontWeight.w600,
              color: night ? PortalTimeOfDay.nightTextColor : null,
              shadows: night ? PortalTimeOfDay.nightTextOutlineShadows : null,
            ),
          ),
          const SizedBox(height: 22),
          if (babyId == null)
            Text(
              s.feedingNoBabyHint,
              style: PortalNightUi.bodyStyle(night).copyWith(
                fontWeight: FontWeight.w700,
                color: night
                    ? PortalTimeOfDay.nightOutlinedTextColor.withAlpha(220)
                    : Colors.black.withAlpha(140),
              ),
            )
          else ...[
            _RegisterRow(
              icon: Icons.monitor_weight_outlined,
              title: s.growth,
              color: AppTheme.secondary,
              onTap: () => pushPortalPage<void>(
                    context, const GrowthRegisterPage()),
            ),
            const SizedBox(height: 10),
            _RegisterRow(
              icon: Icons.restaurant_outlined,
              title: s.shortcutFeedingSession,
              color: const Color(0xFFE08A3E),
              onTap: () => pushPortalPage<void>(
                    context,
                    FeedingHubPage(
                        appBarTitle: s.shortcutFeedingSession),
                  ),
            ),
            const SizedBox(height: 10),
            _RegisterRow(
              icon: Icons.favorite_outline,
              title: s.shortcutHealth,
              color: AppTheme.green,
              onTap: () =>
                  pushPortalPage<void>(context, const HealthHubPage()),
            ),
            const SizedBox(height: 10),
            _RegisterRow(
              icon: Icons.baby_changing_station_rounded,
              title: s.shortcutDiaper,
              color: AppTheme.mint,
              onTap: () =>
                  pushPortalPage<void>(context, const DiaperPage()),
            ),
            const SizedBox(height: 10),
            _RegisterRow(
              icon: Icons.nightlight_round,
              title: s.shortcutSleep,
              color: AppTheme.primary,
              onTap: () =>
                  pushPortalPage<void>(context, const SleepPage()),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, thickness: 1),
            ),
            _RegisterRow(
              icon: Icons.insert_chart_outlined,
              title: s.reportsTitle,
              color: AppTheme.textPrimary,
              onTap: () =>
                  pushPortalPage<void>(context, const ReportsHubPage()),
            ),
          ],
        ],
      ),
    );
    });
  }
}

class _RegisterRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _RegisterRow({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.ctaPrimary.withAlpha(16),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: color.withAlpha(36),
                  child: Icon(icon, color: color, size: 25),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: PortalNightUi.cardTitleStyle(fontSize: 17),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: PortalNightUi.cardChevronColor(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
