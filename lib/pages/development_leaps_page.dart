import 'package:flutter/material.dart';

import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../models/development_leap.dart';
import '../services/development_leaps_service.dart';
import '../theme/app_theme.dart';

class DevelopmentLeapsPage extends StatelessWidget {
  const DevelopmentLeapsPage({super.key});

  String _babyName(S s) {
    final n = (CurrentBabyController.instance.currentBabyRow?['name'] as String?)?.trim();
    return (n == null || n.isEmpty) ? s.baby : n;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final birthRaw = CurrentBabyController.instance.currentBabyRow?['birth_date'] as String?;
    final birth = DateTime.tryParse((birthRaw ?? '').trim());
    final name = _babyName(s);

    return Scaffold(
      appBar: AppBar(title: Text(s.devLeapsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [
            Text(
              s.devLeapsIntro(name),
              style: TextStyle(fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w600, color: Colors.black.withAlpha(150)),
            ),
            const SizedBox(height: 14),
            if (birth == null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE8EAEF)),
                ),
                child: Text(
                  s.devLeapsNeedBirth,
                  style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black.withAlpha(160)),
                ),
              )
            else ...[
              _CurrentLeapCard(birth: birth),
              const SizedBox(height: 14),
              Text(s.devLeapsAllTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              for (final leap in DevelopmentLeapsService.all)
                _LeapListTile(
                  leap: leap,
                  babyName: name,
                  isCurrent: DevelopmentLeapsService.current(birthDate: birth) == leap,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrentLeapCard extends StatelessWidget {
  final DateTime birth;

  const _CurrentLeapCard({required this.birth});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final leap = DevelopmentLeapsService.current(birthDate: birth);
    if (leap == null) return const SizedBox.shrink();
    final name = (CurrentBabyController.instance.currentBabyRow?['name'] as String?)?.trim();
    final babyName = (name == null || name.isEmpty) ? s.baby : name;
    final bk = leap.bannerKey;
    final headline = '${s.developmentLeapBannerRange(bk)} — ${s.developmentLeapBannerTitle(bk)}';
    final lead = s.developmentLeapBannerLead(bk).replaceAll('{baby_name}', babyName);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Color.lerp(Colors.white, AppTheme.primaryPink, 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryPink.withAlpha(55)),
        boxShadow: [
          BoxShadow(color: AppTheme.primaryPink.withAlpha(28), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌱', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
                  style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black.withAlpha(165)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPink.withAlpha(30),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.primaryPink.withAlpha(60)),
                ),
                child: Text(
                  s.devLeapsCurrentPill,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppTheme.primaryPink.withAlpha(230)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            lead,
            style: TextStyle(fontWeight: FontWeight.w700, height: 1.25, color: Colors.black.withAlpha(155)),
          ),
          const SizedBox(height: 8),
          for (final b in s.developmentLeapHomeBullets(bk).take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('• $b', style: TextStyle(height: 1.2, color: Colors.black.withAlpha(150))),
            ),
          const SizedBox(height: 8),
          Text('💜 ${s.developmentLeapBannerEmotion(bk)}',
              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black.withAlpha(150))),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DevelopmentLeapDetailPage(leap: leap)),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(s.devLeapsSeeDetails, style: const TextStyle(fontWeight: FontWeight.w900)),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryPink.withAlpha(26),
                foregroundColor: AppTheme.primaryPink.withAlpha(240),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeapListTile extends StatelessWidget {
  final DevelopmentLeap leap;
  final String babyName;
  final bool isCurrent;

  const _LeapListTile({required this.leap, required this.babyName, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bk = leap.bannerKey;
    final headline = '${s.developmentLeapBannerRange(bk)} — ${s.developmentLeapBannerTitle(bk)}';
    final lead = s.developmentLeapBannerLead(bk).replaceAll('{baby_name}', babyName);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isCurrent ? AppTheme.primaryPink.withAlpha(70) : const Color(0xFFE8EAEF)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color.lerp(Colors.white, AppTheme.primaryPink, isCurrent ? 0.16 : 0.08),
          child: const Text('🌱'),
        ),
        title: Text(headline, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(lead, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        trailing: isCurrent
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPink.withAlpha(22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  s.devLeapsCurrentPill,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppTheme.primaryPink.withAlpha(230)),
                ),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DevelopmentLeapDetailPage(leap: leap))),
      ),
    );
  }
}

class DevelopmentLeapDetailPage extends StatelessWidget {
  final DevelopmentLeap leap;

  const DevelopmentLeapDetailPage({super.key, required this.leap});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final name = (CurrentBabyController.instance.currentBabyRow?['name'] as String?)?.trim();
    final babyName = (name == null || name.isEmpty) ? s.baby : name;
    final bk = leap.bannerKey;
    final headline = '${s.developmentLeapBannerRange(bk)} — ${s.developmentLeapBannerTitle(bk)}';
    final lead = s.developmentLeapBannerLead(bk).replaceAll('{baby_name}', babyName);

    Widget section(String title, Widget child) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8EAEF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black.withAlpha(170))),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
    }

    Widget bullets(List<String> items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $it', style: TextStyle(height: 1.3, color: Colors.black.withAlpha(155))),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(headline)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [
            Text(lead, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.25)),
            const SizedBox(height: 10),
            Text('💜 ${s.developmentLeapBannerEmotion(bk)}',
                style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black.withAlpha(160))),
            const SizedBox(height: 14),
            section(s.devLeapsWhatsHappening,
                Text(s.developmentLeapDetailWhats(bk),
                    style: TextStyle(height: 1.35, color: Colors.black.withAlpha(155)))),
            section(s.devLeapsKeywords, Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in s.developmentLeapDetailKeywords(bk))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color.lerp(Colors.white, AppTheme.primaryPink, 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.primaryPink.withAlpha(55)),
                  ),
                  child: Text(k, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
            ])),
            section(s.devLeapsMayHappen, bullets(s.developmentLeapDetailMayHappen(bk))),
            section(s.devLeapsHowToHelp, bullets(s.developmentLeapDetailHowToHelp(bk))),
            section(s.devLeapsSkills, bullets(s.developmentLeapDetailSkills(bk))),
            section(
                s.devLeapsEmotionalLook,
                Text(s.developmentLeapDetailEmotionalLook(bk),
                    style: TextStyle(height: 1.35, color: Colors.black.withAlpha(155)))),
          ],
        ),
      ),
    );
  }
}

