import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../services/app_tour/app_tour_keys.dart';
import '../../theme/app_theme.dart';

enum AppTourStepKind {
  babyBannerSleep,
  babyBannerFeeding,
  babyBannerDiaper,
  recordsTab,
  aiNannyTab,
  memoriesTab,
  familyPage,
  finish,
}

enum QuickRegisterTourStepKind {
  overview,
  categories,
  reports,
}

class AppTourStep {
  const AppTourStep({
    required this.kind,
    this.targetKeys = const [],
    this.illustrationAsset,
  });

  final AppTourStepKind kind;
  final List<GlobalKey> targetKeys;
  final String? illustrationAsset;
}

class AppTourOverlay extends StatefulWidget {
  const AppTourOverlay({
    super.key,
    required this.stepIndex,
    required this.steps,
    required this.onStepPrepare,
    required this.onNext,
    required this.onSkip,
    required this.onFinish,
  });

  final int stepIndex;
  final List<AppTourStep> steps;
  final Future<void> Function(AppTourStep step) onStepPrepare;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onFinish;

  @override
  State<AppTourOverlay> createState() => _AppTourOverlayState();
}

class _AppTourOverlayState extends State<AppTourOverlay>
    with SingleTickerProviderStateMixin {
  Rect? _hole;
  late AnimationController _pulse;
  bool _preparing = true;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _prepareCurrentStep();
  }

  @override
  void didUpdateWidget(covariant AppTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stepIndex != widget.stepIndex) {
      _prepareCurrentStep();
    }
  }

  Future<void> _prepareCurrentStep() async {
    setState(() => _preparing = true);
    final step = widget.steps[widget.stepIndex];
    await widget.onStepPrepare(step);
    if (!mounted) return;
    await waitForTourTargets(step.targetKeys);
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    _updateHole();
    setState(() => _preparing = false);
  }

  void _updateHole() {
    final step = widget.steps[widget.stepIndex];
    if (step.kind == AppTourStepKind.finish) {
      _hole = null;
      return;
    }
    _hole = _unionTargetRect(step.targetKeys, inflate: 10);
  }

  Rect? _unionTargetRect(List<GlobalKey> keys, {double inflate = 0}) {
    Rect? union;
    for (final key in keys) {
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final offset = box.localToGlobal(Offset.zero);
      final rect = offset & box.size;
      union = union == null ? rect : union.expandToInclude(rect);
    }
    if (union == null) return null;
    if (inflate > 0) {
      union = union.inflate(inflate);
    }
    final screen = MediaQuery.sizeOf(context);
    return Rect.fromLTRB(
      union.left.clamp(0.0, screen.width),
      union.top.clamp(0.0, screen.height),
      union.right.clamp(0.0, screen.width),
      union.bottom.clamp(0.0, screen.height),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  AppTourCopy _copy(S s) {
    switch (widget.steps[widget.stepIndex].kind) {
      case AppTourStepKind.babyBannerSleep:
        return AppTourCopy(
          s.appTourBabyBannerSleepTitle,
          s.appTourBabyBannerSleepBody,
        );
      case AppTourStepKind.babyBannerFeeding:
        return AppTourCopy(
          s.appTourBabyBannerFeedingTitle,
          s.appTourBabyBannerFeedingBody,
        );
      case AppTourStepKind.babyBannerDiaper:
        return AppTourCopy(
          s.appTourBabyBannerDiaperTitle,
          s.appTourBabyBannerDiaperBody,
        );
      case AppTourStepKind.recordsTab:
        return AppTourCopy(s.appTourStep2Title, s.appTourStep2Body);
      case AppTourStepKind.aiNannyTab:
        return AppTourCopy(s.appTourStep3Title, s.appTourStep3Body);
      case AppTourStepKind.memoriesTab:
        return AppTourCopy(s.appTourStep4Title, s.appTourStep4Body);
      case AppTourStepKind.familyPage:
        return AppTourCopy(s.appTourStep5Title, s.appTourStep5Body);
      case AppTourStepKind.finish:
        return AppTourCopy(s.appTourStep6Title, s.appTourStep6Body);
    }
  }

  String? _illustrationFor(AppTourStep step) {
    if (step.illustrationAsset != null) return step.illustrationAsset;
    return switch (step.kind) {
      AppTourStepKind.babyBannerSleep ||
      AppTourStepKind.babyBannerFeeding ||
      AppTourStepKind.babyBannerDiaper =>
        'assets/onboarding/mom_baby.png',
      AppTourStepKind.recordsTab => 'assets/onboarding/date_birth_icon.png',
      AppTourStepKind.aiNannyTab => 'assets/onboarding/cloud_icon.png',
      AppTourStepKind.memoriesTab => 'assets/onboarding/first_baby_icon.png',
      AppTourStepKind.familyPage => 'assets/onboarding/dad_baby.png',
      AppTourStepKind.finish => 'assets/onboarding/logo_welcome.png',
    };
  }

  bool _isBabyBannerStep(AppTourStepKind kind) {
    return kind == AppTourStepKind.babyBannerSleep ||
        kind == AppTourStepKind.babyBannerFeeding ||
        kind == AppTourStepKind.babyBannerDiaper;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final copy = _copy(s);
    final step = widget.steps[widget.stepIndex];
    final isLast = widget.stepIndex >= widget.steps.length - 1;
    final illustration = _illustrationFor(step) ?? 'assets/onboarding/logo.png';

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_preparing)
            const ColoredBox(color: Color(0x99000000))
          else
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                return CustomPaint(
                  painter: _CoachMarkPainter(
                    hole: _hole,
                    pulse: step.kind == AppTourStepKind.finish ? 0 : _pulse.value,
                  ),
                );
              },
            ),
          _CoachMarkCardLayout(
            hole: _hole,
            centerCard: step.kind == AppTourStepKind.familyPage ||
                step.kind == AppTourStepKind.finish,
            preferBelowTarget: _isBabyBannerStep(step.kind),
            skipLabel: s.appTourSkip,
            onSkip: widget.onSkip,
            card: AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _TourCard(
                key: ValueKey(widget.stepIndex),
                title: copy.title,
                body: copy.body,
                illustrationAsset: illustration,
                stepLabel: s.appTourProgress(
                  widget.stepIndex + 1,
                  widget.steps.length,
                ),
                primaryLabel: isLast ? s.appTourFinish : s.appTourNext,
                onPrimary: isLast ? widget.onFinish : widget.onNext,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppTourCopy {
  const AppTourCopy(this.title, this.body);
  final String title;
  final String body;
}

/// Posiciona o cartão do tour acima ou abaixo do alvo, sem cobrir os botões.
class _CoachMarkCardLayout extends StatelessWidget {
  const _CoachMarkCardLayout({
    required this.hole,
    required this.skipLabel,
    required this.onSkip,
    required this.card,
    this.centerCard = false,
    this.preferBelowTarget = false,
  });

  final Rect? hole;
  final String skipLabel;
  final VoidCallback onSkip;
  final Widget card;
  final bool centerCard;
  final bool preferBelowTarget;

  static const _horizontalPad = 18.0;
  static const _gap = 20.0;
  static const _skipRowHeight = 48.0;
  static const _minCardHeight = 160.0;

  bool _preferAboveHole(
    Rect target,
    Size screen,
    double safeTop,
    double safeBottom,
  ) {
    if (preferBelowTarget) {
      final spaceBelow =
          screen.height - target.bottom - _gap - safeBottom - 12;
      return spaceBelow < _minCardHeight;
    }
    if (target.bottom >= screen.height - 108) return true;
    if (target.center.dy < screen.height * 0.58) return false;
    final spaceAbove = target.top - _gap - safeTop - _skipRowHeight;
    final spaceBelow =
        screen.height - target.bottom - _gap - safeBottom - 12;
    return spaceAbove >= spaceBelow;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    final safeTop = media.padding.top;
    final safeBottom = media.padding.bottom;

    Widget positionedCard;
    if (centerCard || hole == null) {
      positionedCard = Align(
        alignment: const Alignment(0, -0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPad),
          child: card,
        ),
      );
    } else if (_preferAboveHole(hole!, screen, safeTop, safeBottom)) {
      final maxHeight = (hole!.top - _gap - safeTop - _skipRowHeight)
          .clamp(120.0, screen.height);
      positionedCard = Positioned(
        left: _horizontalPad,
        right: _horizontalPad,
        bottom: screen.height - hole!.top + _gap,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: card,
          ),
        ),
      );
    } else {
      final maxHeight = (screen.height - hole!.bottom - _gap - safeBottom - 12)
          .clamp(120.0, screen.height);
      positionedCard = Positioned(
        left: _horizontalPad,
        right: _horizontalPad,
        top: hole!.bottom + _gap,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: card,
          ),
        ),
      );
    }

    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: TextButton(
              onPressed: onSkip,
              child: Text(
                skipLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          positionedCard,
        ],
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    super.key,
    required this.title,
    required this.body,
    required this.illustrationAsset,
    required this.stepLabel,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final String title;
  final String body;
  final String illustrationAsset;
  final String stepLabel;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final accent = Color.lerp(AppTheme.primaryPink, AppTheme.primaryPurple, 0.35)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: accent.withAlpha(55),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    illustrationAsset,
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.auto_awesome_rounded,
                      size: 48,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stepLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onPrimary,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  primaryLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachMarkPainter extends CustomPainter {
  _CoachMarkPainter({required this.hole, required this.pulse});

  final Rect? hole;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    final paint = Paint()..color = const Color(0xCC101828);

    if (hole == null) {
      canvas.drawPath(overlay, paint);
      return;
    }

    final r = hole!;
    final radius = 18.0 + pulse * 4;
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
    final combined = Path.combine(PathOperation.difference, overlay, holePath);
    canvas.drawPath(combined, paint);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 + pulse
      ..color = Color.lerp(AppTheme.primaryPink, AppTheme.primaryPurple, pulse)!
          .withAlpha(180 + (pulse * 40).round());
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(radius)),
      ring,
    );
  }

  @override
  bool shouldRepaint(covariant _CoachMarkPainter oldDelegate) {
    return oldDelegate.hole != hole || oldDelegate.pulse != pulse;
  }
}

List<AppTourStep> defaultAppTourSteps() => [
      AppTourStep(
        kind: AppTourStepKind.babyBannerSleep,
        targetKeys: [AppTourKeys.babyBannerSleep],
      ),
      AppTourStep(
        kind: AppTourStepKind.babyBannerFeeding,
        targetKeys: [AppTourKeys.babyBannerFeeding],
      ),
      AppTourStep(
        kind: AppTourStepKind.babyBannerDiaper,
        targetKeys: [AppTourKeys.babyBannerDiaper],
      ),
      AppTourStep(
        kind: AppTourStepKind.recordsTab,
        targetKeys: [AppTourKeys.navRecords],
      ),
      AppTourStep(
        kind: AppTourStepKind.aiNannyTab,
        targetKeys: [AppTourKeys.navAiNanny],
      ),
      AppTourStep(
        kind: AppTourStepKind.memoriesTab,
        targetKeys: [AppTourKeys.navMemories],
      ),
      AppTourStep(
        kind: AppTourStepKind.familyPage,
        targetKeys: [AppTourKeys.familyTree],
      ),
      const AppTourStep(kind: AppTourStepKind.finish),
    ];

class QuickRegisterTourStep {
  const QuickRegisterTourStep({
    required this.kind,
    this.targetKeys = const [],
  });

  final QuickRegisterTourStepKind kind;
  final List<GlobalKey> targetKeys;
}

class QuickRegisterTourOverlay extends StatefulWidget {
  const QuickRegisterTourOverlay({
    super.key,
    required this.stepIndex,
    required this.steps,
    required this.onStepPrepare,
    required this.onNext,
    required this.onSkip,
    required this.onFinish,
  });

  final int stepIndex;
  final List<QuickRegisterTourStep> steps;
  final Future<void> Function(QuickRegisterTourStep step) onStepPrepare;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onFinish;

  @override
  State<QuickRegisterTourOverlay> createState() =>
      _QuickRegisterTourOverlayState();
}

class _QuickRegisterTourOverlayState extends State<QuickRegisterTourOverlay>
    with SingleTickerProviderStateMixin {
  Rect? _hole;
  late AnimationController _pulse;
  bool _preparing = true;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _prepareCurrentStep();
  }

  @override
  void didUpdateWidget(covariant QuickRegisterTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stepIndex != widget.stepIndex) {
      _prepareCurrentStep();
    }
  }

  Future<void> _prepareCurrentStep() async {
    setState(() => _preparing = true);
    final step = widget.steps[widget.stepIndex];
    await widget.onStepPrepare(step);
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    _updateHole();
    setState(() => _preparing = false);
  }

  void _updateHole() {
    final step = widget.steps[widget.stepIndex];
    _hole = _unionTargetRect(step.targetKeys, inflate: 10);
  }

  Rect? _unionTargetRect(List<GlobalKey> keys, {double inflate = 0}) {
    Rect? union;
    for (final key in keys) {
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final offset = box.localToGlobal(Offset.zero);
      final rect = offset & box.size;
      union = union == null ? rect : union.expandToInclude(rect);
    }
    if (union == null) return null;
    if (inflate > 0) {
      union = union.inflate(inflate);
    }
    final screen = MediaQuery.sizeOf(context);
    return Rect.fromLTRB(
      union.left.clamp(0.0, screen.width),
      union.top.clamp(0.0, screen.height),
      union.right.clamp(0.0, screen.width),
      union.bottom.clamp(0.0, screen.height),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  AppTourCopy _copy(S s) {
    switch (widget.steps[widget.stepIndex].kind) {
      case QuickRegisterTourStepKind.overview:
        return AppTourCopy(
          s.quickRegTourStep1Title,
          s.quickRegTourStep1Body,
        );
      case QuickRegisterTourStepKind.categories:
        return AppTourCopy(
          s.quickRegTourStep2Title,
          s.quickRegTourStep2Body,
        );
      case QuickRegisterTourStepKind.reports:
        return AppTourCopy(
          s.quickRegTourStep3Title,
          s.quickRegTourStep3Body,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final copy = _copy(s);
    final isLast = widget.stepIndex >= widget.steps.length - 1;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_preparing)
            const ColoredBox(color: Color(0x99000000))
          else
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                return CustomPaint(
                  painter: _CoachMarkPainter(
                    hole: _hole,
                    pulse: _pulse.value,
                  ),
                );
              },
            ),
          _CoachMarkCardLayout(
            hole: _hole,
            skipLabel: s.appTourSkip,
            onSkip: widget.onSkip,
            card: AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _TourCard(
                key: ValueKey(widget.stepIndex),
                title: copy.title,
                body: copy.body,
                illustrationAsset: 'assets/onboarding/date_birth_icon.png',
                stepLabel: s.appTourProgress(
                  widget.stepIndex + 1,
                  widget.steps.length,
                ),
                primaryLabel: isLast ? s.appTourFinish : s.appTourNext,
                onPrimary: isLast ? widget.onFinish : widget.onNext,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<QuickRegisterTourStep> defaultQuickRegisterTourSteps() => [
      QuickRegisterTourStep(
        kind: QuickRegisterTourStepKind.overview,
        targetKeys: [AppTourKeys.quickRegisterHeader],
      ),
      QuickRegisterTourStep(
        kind: QuickRegisterTourStepKind.categories,
        targetKeys: [AppTourKeys.quickRegisterCategories],
      ),
      QuickRegisterTourStep(
        kind: QuickRegisterTourStepKind.reports,
        targetKeys: [AppTourKeys.quickRegisterReports],
      ),
    ];

Future<void> waitForTourTarget(GlobalKey key, {int attempts = 30}) async {
  for (var i = 0; i < attempts; i++) {
    if (key.currentContext != null) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

Future<void> waitForTourTargets(List<GlobalKey> keys) async {
  for (final key in keys) {
    await waitForTourTarget(key);
  }
}

Future<void> ensureVisibleForTour(
  GlobalKey key, {
  double alignment = 0.25,
}) async {
  final ctx = key.currentContext;
  if (ctx == null) return;
  await Scrollable.ensureVisible(
    ctx,
    duration: const Duration(milliseconds: 420),
    curve: Curves.easeOutCubic,
    alignment: alignment,
  );
}
