import 'package:flutter/material.dart';

import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../services/premium/feature_access.dart';
import '../../services/premium/premium_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/portal_layout.dart';
import '../../utils/portal_page_route.dart';
import 'report_page_shell.dart';
import '../../widgets/premium_locked_content_card.dart';
import '../premium/premium_paywall_screen.dart';
import 'advanced_sleep_report_page.dart';
import 'daily_report_page.dart';
import 'monthly_report_page.dart';
import 'pediatric_report_page.dart';
import 'weekly_report_page.dart';

/// Hub dos relatórios. A data / período escolhe-se **dentro de cada relatório**, não aqui.
class ReportsHubPage extends StatelessWidget {
  const ReportsHubPage({super.key});

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _openDaily(BuildContext context) {
    pushPortalPage<void>(
      context,
      DailyReportPage(initialDay: _today()),
    );
  }

  void _openWeekly(BuildContext context) {
    pushPortalPage<void>(
      context,
      WeeklyReportPage(anchorDay: _today()),
    );
  }

  void _openMonthly(BuildContext context) {
    if (!FeatureAccess.canOpenAdvancedReports) {
      openPremiumPaywall(context);
      return;
    }
    pushPortalPage<void>(
      context,
      MonthlyReportPage(anchorDay: _today()),
    );
  }

  void _openSleepAdv(BuildContext context) {
    if (!FeatureAccess.canOpenAdvancedReports) {
      openPremiumPaywall(context);
      return;
    }
    pushPortalPage<void>(
      context,
      AdvancedSleepReportPage(anchorDay: _today()),
    );
  }

  void _openPediatric(BuildContext context) {
    if (!FeatureAccess.canOpenAdvancedReports) {
      openPremiumPaywall(context);
      return;
    }
    pushPortalPage<void>(
      context,
      PediatricReportPage(anchorDay: _today()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final babyId = CurrentBabyController.instance.currentBabyId;
    final nightBackground = reportScaffoldBackground();

    return Scaffold(
      backgroundColor: nightBackground,
      appBar: AppBar(
        backgroundColor: nightBackground,
        surfaceTintColor: nightBackground,
        title: Text(s.reportsTitle),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: PremiumService.instance,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  AppTheme.pageHPadding, 18, AppTheme.pageHPadding, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.reportsSubtitle,
                    style: TextStyle(
                        fontSize: portalSp(context, 15),
                        color: AppTheme.textMuted,
                        height: 1.35),
                  ),
                  if (babyId == null) ...[
                    const SizedBox(height: 18),
                    Text(
                      s.feedingNoBabyHint,
                      style: TextStyle(
                          color: Colors.black.withAlpha(140),
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(s.reportsHubSectionTitle,
                      style: TextStyle(
                          fontSize: portalSp(context, 13),
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMuted)),
                  const SizedBox(height: 10),
                  _ReportTile(
                    icon: Icons.today_rounded,
                    color: AppTheme.primaryPink,
                    title: s.reportListDaily,
                    subtitle: s.reportListDailySub,
                    onTap: () => _openDaily(context),
                  ),
                  const SizedBox(height: 10),
                  _ReportTile(
                    icon: Icons.date_range_rounded,
                    color: AppTheme.ctaPrimary,
                    title: s.reportListWeekly,
                    subtitle: s.reportListWeeklySub,
                    onTap: () => _openWeekly(context),
                  ),
                  const SizedBox(height: 10),
                  _ReportTile(
                    icon: Icons.calendar_view_month_rounded,
                    color: AppTheme.green,
                    title: s.reportListMonthly,
                    subtitle: s.reportListMonthlySub,
                    locked: !FeatureAccess.canOpenAdvancedReports,
                    onTap: () => _openMonthly(context),
                  ),
                  const SizedBox(height: 10),
                  _ReportTile(
                    icon: Icons.bedtime_rounded,
                    color: AppTheme.primary,
                    title: s.reportListSleepAdv,
                    subtitle: s.reportListSleepAdvSub,
                    locked: !FeatureAccess.canOpenAdvancedReports,
                    onTap: () => _openSleepAdv(context),
                  ),
                  const SizedBox(height: 10),
                  _ReportTile(
                    icon: Icons.medical_services_outlined,
                    color: AppTheme.mint,
                    title: s.reportListPediatric,
                    subtitle: s.reportListPediatricSub,
                    locked: !FeatureAccess.canOpenAdvancedReports,
                    onTap: () => _openPediatric(context),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    if (locked) {
      final s = S.of(context);
      return PremiumLockedContentCard(
        title: title,
        tagline: s.plusReportsPremiumTagline,
        subtitle: subtitle,
        ctaLabel: s.plusReportsPremiumCta,
        onTap: onTap,
        compact: true,
        accent: color,
        vibrant: true,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(locked ? 28 : 50)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.ctaPrimary.withAlpha(14),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: color.withAlpha(locked ? 22 : 36),
                      child: Icon(icon,
                          color: color.withAlpha(locked ? 170 : 255), size: 24),
                    ),
                    if (locked)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Icon(Icons.lock_rounded,
                            size: 16, color: Colors.black.withAlpha(140)),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                                color: AppTheme.textPrimary
                                    .withAlpha(locked ? 200 : 255),
                              ),
                            ),
                          ),
                          if (locked)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C6BA8).withAlpha(36),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'PLUS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                  color: const Color(0xFF5B4B86),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.25,
                          color:
                              AppTheme.textMuted.withAlpha(locked ? 200 : 255),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.black.withAlpha(locked ? 55 : 90)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
