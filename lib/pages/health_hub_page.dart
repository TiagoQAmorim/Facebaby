import 'package:flutter/material.dart';
import '../i18n/app_i18n.dart';
import '../services/home_prefs.dart';
import '../theme/app_theme.dart';
import '../utils/portal_layout.dart';
import '../widgets/card_box.dart';
import '../widgets/section_title.dart';
import 'consultations_page.dart';
import 'vaccines_page.dart';

class HealthHubPage extends StatelessWidget {
  const HealthHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.healthHubTitle)),
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
                    style: TextStyle(color: Colors.black.withAlpha(140), fontWeight: FontWeight.w600, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  ValueListenableBuilder<bool>(
                    valueListenable: HomePrefs.growthHealthAlertsEnabled,
                    builder: (context, enabled, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(Icons.notifications_active_outlined, color: AppTheme.green.withAlpha(220)),
                        title: Text(s.healthGrowthToggleAlerts, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        subtitle: Text(s.healthGrowthToggleAlertsSubtitle, style: TextStyle(fontSize: 12, color: Colors.black.withAlpha(130))),
                        value: enabled,
                        activeThumbColor: AppTheme.green,
                        onChanged: (v) => HomePrefs.setGrowthHealthAlertsEnabled(v),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  SectionTitle(title: s.healthHubSection),
                  const SizedBox(height: 12),
                  _HubTile(
                    icon: Icons.vaccines_outlined,
                    color: AppTheme.green,
                    softBg: AppTheme.softMint,
                    title: s.healthHubVaccines,
                    subtitle: s.healthHubVaccinesSub,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VaccinesPage())),
                  ),
                  const SizedBox(height: 12),
                  _HubTile(
                    icon: Icons.medical_information_outlined,
                    color: AppTheme.primary,
                    softBg: AppTheme.softPurple,
                    title: s.healthHubConsultations,
                    subtitle: s.healthHubConsultationsSub,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsultationsPage())),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
            CircleAvatar(radius: 26, backgroundColor: softBg, child: Icon(icon, color: color, size: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 3,
                    softWrap: true,
                    style: TextStyle(fontSize: portalSp(context, 17), fontWeight: FontWeight.w900, height: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 5,
                    softWrap: true,
                    style: TextStyle(color: Colors.black.withAlpha(130), fontWeight: FontWeight.w600, height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
