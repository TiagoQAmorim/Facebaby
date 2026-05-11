import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../models/development_report_snapshot.dart';
import '../../services/development_report_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/portal_layout.dart';
import '../../widgets/photo_avatar.dart';
import '../development_leaps_page.dart';

/// Relatório de desenvolvimento — marcos por idade, score suave e tom acolhedor.
class DevelopmentReportPage extends StatefulWidget {
  const DevelopmentReportPage({super.key, required this.anchorDay});

  final DateTime anchorDay;

  @override
  State<DevelopmentReportPage> createState() => _DevelopmentReportPageState();
}

class _DevelopmentReportPageState extends State<DevelopmentReportPage> with SingleTickerProviderStateMixin {
  DevelopmentReportSnapshot? _snapshot;
  final _babyCtrl = CurrentBabyController.instance;
  late AnimationController _gaugeAnim;

  static const _purple = Color(0xFF8E7CC3);
  static const _green = Color(0xFF34C759);
  static const _bg = Color(0xFFF5F3FA);
  static const _cardTint = Color(0xFFF2F0FA);

  @override
  void initState() {
    super.initState();
    _gaugeAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _babyCtrl.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _gaugeAnim.dispose();
    _babyCtrl.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    final birthRaw = _babyCtrl.currentBabyRow?['birth_date'] as String?;
    final birth = DateTime.tryParse(birthRaw ?? '');
    final ref = DateTime(widget.anchorDay.year, widget.anchorDay.month, widget.anchorDay.day);
    if (birth != null) {
      final snap = DevelopmentReportService.load(birthDate: birth, referenceDay: ref);
      setState(() => _snapshot = snap);
      _gaugeAnim.forward(from: 0);
    } else {
      setState(() => _snapshot = null);
    }
  }

  String _statusLabel(S s, DevelopmentReportSnapshot snap) {
    switch (snap.statusKey) {
      case 'on_track':
        return s.reportDevScoreStatusOnTrack;
      case 'early':
        return s.reportDevScoreStatusEarly;
      default:
        return s.reportDevScoreStatusWatch;
    }
  }

  String _insightText(S s, DevelopmentReportSnapshot snap) {
    switch (snap.insightKey) {
      case 'devReportInsightNewborn':
        return s.devReportInsightNewborn;
      case 'devReportInsightOnTrack':
        return s.devReportInsightOnTrack;
      case 'devReportInsightVariety':
        return s.devReportInsightVariety;
      case 'devReportInsightPatience':
        return s.devReportInsightPatience;
      default:
        return s.devReportInsightBalanced;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final babyRow = _babyCtrl.currentBabyRow;
    final birthRaw = babyRow?['birth_date'] as String?;
    final birth = DateTime.tryParse(birthRaw ?? '');
    final name = (babyRow?['name'] as String?)?.trim();
    final babyName = (name == null || name.isEmpty) ? s.placeholderBabyName : name;
    final snap = _snapshot;
    final refDay = DateTime(widget.anchorDay.year, widget.anchorDay.month, widget.anchorDay.day);
    final ageTitle = birth != null ? s.babyAgeLabel(birth, refDay) : '—';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(s.reportDevScreenTitle, style: const TextStyle(fontWeight: FontWeight.w900, color: _purple)),
      ),
      body: birth == null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(s.reportDevNeedBirth)))
          : snap == null
              ? const Center(child: CircularProgressIndicator.adaptive())
              : RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(AppTheme.pageHPadding, 8, AppTheme.pageHPadding, 110),
                    children: [
                      Text(
                        ageTitle,
                        style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w700, fontSize: portalSp(context, 15)),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PhotoAvatar(
                            photoB64: babyRow?['photo_b64'] as String?,
                            photoUrl: ((babyRow?['photo_url'] as String?) ?? '').trim().isEmpty
                                ? null
                                : (babyRow?['photo_url'] as String?)?.trim(),
                            radius: 30,
                            backgroundColor: AppTheme.softPurple,
                            fallback: const Text('👶', style: TextStyle(fontSize: 30)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(babyName, style: TextStyle(fontWeight: FontWeight.w900, fontSize: portalSp(context, 20), color: _purple)),
                                Text(s.reportDevSubtitle, style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _scoreCard(context, s, snap),
                      const SizedBox(height: 18),
                      _sectionCard(
                        context,
                        title: s.reportDevSectionMotor,
                        tint: _cardTint,
                        children: snap.motor.map((m) => _milestoneRow(context, s, m)).toList(),
                      ),
                      const SizedBox(height: 12),
                      _sectionCard(
                        context,
                        title: s.reportDevSectionCognitive,
                        tint: _cardTint,
                        children: snap.cognitive.map((m) => _milestoneRow(context, s, m)).toList(),
                      ),
                      const SizedBox(height: 12),
                      _sectionCard(
                        context,
                        title: s.reportDevSectionSocial,
                        tint: _cardTint,
                        children: snap.social.map((m) => _milestoneRow(context, s, m)).toList(),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded, color: _purple.withAlpha(220), size: 22),
                                const SizedBox(width: 8),
                                Text(s.reportDevInsightTitle, style: TextStyle(fontWeight: FontWeight.w900, fontSize: portalSp(context, 16), color: _purple)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(_insightText(s, snap), style: const TextStyle(height: 1.4, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Material(
                        color: const Color(0xFFD9D3F0),
                        borderRadius: BorderRadius.circular(22),
                        elevation: 0,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const DevelopmentLeapsPage()),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                s.reportDevSeeAllMarcos,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF4A3F6B)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(s.reportDevFootnote, style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.35)),
                    ],
                  ),
                ),
    );
  }

  Widget _scoreCard(BuildContext context, S s, DevelopmentReportSnapshot snap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: _purple.withAlpha(35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.reportDevScoreTitle, style: TextStyle(fontWeight: FontWeight.w900, fontSize: portalSp(context, 17), color: _purple)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _gaugeAnim,
                        builder: (ctx, _) {
                          return CustomPaint(
                            size: const Size(double.infinity, 130),
                            painter: _DevGaugePainter(
                              progress: (snap.developmentScore / 100) * _gaugeAnim.value,
                              purple: _purple,
                            ),
                          );
                        },
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _gaugeAnim,
                            builder: (ctx, _) {
                              final v = (snap.developmentScore * _gaugeAnim.value).round();
                              return Text(
                                '$v%',
                                style: TextStyle(fontSize: portalSp(context, 36), fontWeight: FontWeight.w900, height: 1, color: _purple),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _statusLabel(s, snap),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _green),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/sleep/baby_sleep.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.child_care_rounded, size: 96, color: _purple.withAlpha(160)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {required String title, required Color tint, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: portalSp(context, 16), color: _purple)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _milestoneRow(BuildContext context, S s, DevelopmentMilestoneItem m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            m.achieved ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 22,
            color: m.achieved ? _green : AppTheme.textMuted.withAlpha(180),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.devReportMilestoneLabel(m.id),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: portalSp(context, 14.5), height: 1.3),
            ),
          ),
          Text(
            m.achieved ? s.reportDevAchieved : s.reportDevGrowing,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: m.achieved ? _green : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DevGaugePainter extends CustomPainter {
  _DevGaugePainter({required this.progress, required this.purple});

  final double progress;
  final Color purple;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.92;
    final r = math.min(size.width, size.height * 1.2) / 2;

    final bg = Paint()
      ..color = purple.withAlpha(45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..shader = LinearGradient(colors: [purple, purple.withAlpha(200)]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawArc(rect, math.pi, math.pi, false, bg);
    final sweep = math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(rect, math.pi, sweep, false, fg);
  }

  @override
  bool shouldRepaint(covariant _DevGaugePainter oldDelegate) => oldDelegate.progress != progress;
}
