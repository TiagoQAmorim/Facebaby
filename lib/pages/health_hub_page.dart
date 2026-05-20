import 'package:flutter/material.dart';
import '../i18n/app_i18n.dart';
import '../services/home_prefs.dart';
import '../theme/app_theme.dart';
import '../utils/portal_night_ui.dart';
import '../utils/portal_time_of_day.dart';
import '../utils/portal_page_route.dart';
import '../widgets/card_box.dart';
import '../widgets/section_title.dart';
import 'consultations_page.dart';
import 'symptom_reports_page.dart';
import 'vaccines_page.dart';

class HealthHubPage extends StatelessWidget {
  const HealthHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PortalNightUi.listen((context, night) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PortalNightUi.appBar(s.healthHubTitle, night: night),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.healthHubIntro,
                      style: PortalNightUi.bodyStyle(night, fontSize: 14).copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: night
                            ? PortalTimeOfDay.nightOutlinedTextColor
                            : Colors.black.withAlpha(140),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ValueListenableBuilder<bool>(
                      valueListenable: HomePrefs.growthHealthAlertsEnabled,
                      builder: (context, enabled, _) {
                        return SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(
                            Icons.notifications_active_outlined,
                            color: PortalNightUi.alertIconColor(
                                night, AppTheme.green),
                          ),
                          title: Text(
                            s.healthGrowthToggleAlerts,
                            style: PortalNightUi.alertTitleStyle(night),
                          ),
                          subtitle: Text(
                            s.healthGrowthToggleAlertsSubtitle,
                            style: PortalNightUi.alertSubtitleStyle(night),
                          ),
                          value: enabled,
                          activeThumbColor: AppTheme.green,
                          onChanged: (v) =>
                              HomePrefs.setGrowthHealthAlertsEnabled(v),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    SectionTitle(
                      title: s.healthHubSection,
                      titleColor: night ? PortalTimeOfDay.nightTextColor : null,
                      titleShadows: night
                          ? PortalTimeOfDay.nightTextOutlineShadows
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _HubTile(
                      icon: Icons.vaccines_outlined,
                      color: AppTheme.green,
                      softBg: AppTheme.softMint,
                      title: s.healthHubVaccines,
                      subtitle: s.healthHubVaccinesSub,
                      onTap: () =>
                          pushPortalPage<void>(context, const VaccinesPage()),
                    ),
                    const SizedBox(height: 12),
                    _HubTile(
                      icon: Icons.medical_information_outlined,
                      color: AppTheme.primary,
                      softBg: AppTheme.softPurple,
                      title: s.healthHubConsultations,
                      subtitle: s.healthHubConsultationsSub,
                      onTap: () => pushPortalPage<void>(
                          context, const ConsultationsPage()),
                    ),
                    const SizedBox(height: 12),
                    _HubTile(
                      icon: Icons.healing_outlined,
                      color: AppTheme.green,
                      softBg: AppTheme.softMint,
                      title: s.healthHubSymptomReports,
                      subtitle: s.healthHubSymptomReportsSub,
                      onTap: () => pushPortalPage<void>(
                          context, const SymptomReportsPage()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color softBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.color,
    required this.softBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: softBg,
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 3,
                    softWrap: true,
                    style: PortalNightUi.cardTitleStyle(fontSize: 17),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 5,
                    softWrap: true,
                    style: PortalNightUi.cardSubtitleStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: PortalNightUi.cardChevronColor()),
          ],
        ),
      ),
    );
  }
}
