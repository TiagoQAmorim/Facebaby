// ignore_for_file: prefer_const_constructors, prefer_const_declarations

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../services/premium/premium_constants.dart';
import '../../services/premium/premium_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/portal_page_route.dart';

/// Abre a tela de planos FaceBaby Plus (assinaturas mensal e anual).
Future<void> openPremiumPaywall(BuildContext context) {
  return Navigator.of(context).push<void>(
    portalPageRoute<void>(
      builder: (_) => const PremiumPaywallScreen(),
    ),
  );
}

Future<void> showMemoryPremiumLimitDialog(BuildContext context) async {
  final s = S.of(context);
  final max = '${PremiumConstants.freeMemoryMomentsMax}';
  final subscribe = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: Text(s.plusMemoryLimitDialogTitle),
      content: Text(
        s.plusMemoryLimitDialogBody.replaceAll('{max}', max),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(s.commonClose),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(s.plusMemoryLimitDialogSubscribe),
        ),
      ],
    ),
  );
  if (subscribe == true && context.mounted) {
    await openPremiumPaywall(context);
  }
}

class PremiumPaywallScreen extends StatefulWidget {
  const PremiumPaywallScreen({super.key});

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

enum _PurchasingPlan { none, monthly, annual, restore }

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen>
    with WidgetsBindingObserver {
  _PurchasingPlan _purchasing = _PurchasingPlan.none;

  bool get _busy => _purchasing != _PurchasingPlan.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PremiumService.instance.refreshStorePricing();
      unawaited(PremiumService.instance.syncPremiumFromFirestore());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PremiumService.instance.refreshStorePricing();
      unawaited(PremiumService.instance.syncPremiumFromFirestore());
    }
  }

  Future<void> _purchase({required bool annual}) async {
    if (_busy) return;
    setState(() {
      _purchasing = annual ? _PurchasingPlan.annual : _PurchasingPlan.monthly;
    });
    try {
      final svc = PremiumService.instance;
      final result =
          annual ? await svc.purchaseAnnual() : await svc.purchaseMonthly();
      if (!mounted) return;
      if (svc.isPremium) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).plusWelcomeSnack)),
        );
        return;
      }
      final sku = annual
          ? PremiumConstants.productIdAnnual
          : PremiumConstants.productIdMonthly;
      switch (result) {
        case PurchasePremiumResult.billingFlowLaunched:
          break;
        case PurchasePremiumResult.productNotFoundInStore:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context).plusPurchaseSkuNotFoundSnack(sku)),
            ),
          );
          break;
        case PurchasePremiumResult.billingLaunchFailed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(S.of(context).plusPurchaseBillingLaunchFailedSnack),
              duration: const Duration(seconds: 8),
            ),
          );
          break;
        case PurchasePremiumResult.billingUnavailable:
        case PurchasePremiumResult.unsupportedPlatform:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context).plusPurchaseUnavailableSnack),
            ),
          );
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).plusPurchaseErrorSnack)),
      );
    } finally {
      if (mounted) {
        setState(() => _purchasing = _PurchasingPlan.none);
      }
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _purchasing = _PurchasingPlan.restore);
    try {
      await PremiumService.instance.restorePurchases();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      if (PremiumService.instance.isPremium) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).plusRestoreOkSnack)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).plusRestoreEmptySnack)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).plusPurchaseErrorSnack)),
      );
    } finally {
      if (mounted) setState(() => _purchasing = _PurchasingPlan.none);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final plusPink =
        Color.lerp(AppTheme.primaryPink, AppTheme.primaryPurple, 0.22)!;
    final plusPurple = AppTheme.primaryPurple;

    return ListenableBuilder(
      listenable: PremiumService.instance,
      builder: (context, _) {
        final svc = PremiumService.instance;
        final hasPlus = svc.isPremium;
        final activePlan = svc.activeBillingPlan;
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final savingsLine = s.plusAnnualSavingsAmountLine(
          PremiumConstants.annualSavingsAmountBr,
        );

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(Colors.white, plusPink, 0.12)!,
                        AppTheme.background,
                        Color.lerp(AppTheme.background, plusPurple, 0.04)!,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Image.asset(
                                'assets/onboarding/logo.png',
                                width: 200,
                                height: 70,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              s.plusBrandTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                color: plusPink,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              s.plusPaywallHeadline,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 17,
                                height: 1.3,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _PlanCard(
                              title: s.plusPlanFreeTitle,
                              subtitle: s.plusPlanFreeSubtitle,
                              price: s.plusPlanFreePrice,
                              features: s.plusPlanFreeFeatures,
                              accent: plusPurple,
                              icon: Icons.eco_rounded,
                              ctaLabel: activePlan == PremiumBillingPlan.free
                                  ? s.plusPlanCurrent
                                  : s.plusPlanFreeTitle,
                              isCurrentPlan:
                                  activePlan == PremiumBillingPlan.free,
                              onPressed: null,
                            ),
                            const SizedBox(height: 14),
                            _PlanCard(
                              title: s.plusPlanAnnualCardTitle,
                              subtitle: s.plusPlanAnnualSubtitle,
                              price: svc.formattedLocalizedPriceAnnual,
                              priceHighlight: savingsLine,
                              priceHint: s.plusAnnualPerMonthHint,
                              features: s.plusPlanAnnualFeatures,
                              accent: plusPink,
                              icon: Icons.favorite_rounded,
                              highlighted: true,
                              badge: s.plusPopularBadge,
                              ctaLabel:
                                  activePlan == PremiumBillingPlan.annual
                                      ? s.plusPlanPremiumButtonActive
                                      : s.plusCtaSubscribeAnnual,
                              isCurrentPlan:
                                  activePlan == PremiumBillingPlan.annual,
                              busy: _purchasing == _PurchasingPlan.annual,
                              onPressed: activePlan == PremiumBillingPlan.annual
                                  ? null
                                  : () => _purchase(annual: true),
                            ),
                            const SizedBox(height: 12),
                            _PlanCard(
                              title: s.plusPlanMonthlyCardTitle,
                              subtitle: s.plusPlanMonthlySubtitle,
                              price: svc.formattedLocalizedPriceMonthly,
                              features: s.plusPlanMonthlyFeatures,
                              accent: plusPurple,
                              icon: Icons.workspace_premium_rounded,
                              ctaLabel:
                                  activePlan == PremiumBillingPlan.monthly
                                      ? s.plusPlanPremiumButtonActive
                                      : s.plusCtaSubscribeMonthly,
                              isCurrentPlan:
                                  activePlan == PremiumBillingPlan.monthly,
                              busy: _purchasing == _PurchasingPlan.monthly,
                              onPressed:
                                  activePlan == PremiumBillingPlan.monthly
                                      ? null
                                      : () => _purchase(annual: false),
                            ),
                            const SizedBox(height: 18),
                            const _TrustStrip(),
                            const SizedBox(height: 14),
                            Text(
                              hasPlus
                                  ? s.plusPaywallActiveNote
                                  : s.plusPaywallRenewalNote,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMuted.withAlpha(220),
                              ),
                            ),
                            if (!hasPlus &&
                                svc.storeAvailable &&
                                svc.monthlyProduct == null &&
                                svc.annualProduct == null) ...[
                              const SizedBox(height: 12),
                              Text(
                                s.plusPaywallSkuMissingHint(
                                  PremiumConstants.productIdMonthly,
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!hasPlus)
                      Padding(
                        padding:
                            EdgeInsets.fromLTRB(20, 8, 20, 12 + bottomInset),
                        child: Column(
                          children: [
                            TextButton(
                              onPressed: _busy ? null : _restore,
                              child: Text(
                                s.plusCtaRestore,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: plusPink,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: Text(
                                s.plusCtaLater,
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.features,
    required this.accent,
    required this.icon,
    required this.ctaLabel,
    this.priceHighlight,
    this.priceHint,
    this.badge,
    this.highlighted = false,
    this.isCurrentPlan = false,
    this.busy = false,
    this.onPressed,
  });

  final String title;
  final String subtitle;
  final String price;
  final String? priceHighlight;
  final String? priceHint;
  final List<String> features;
  final Color accent;
  final IconData icon;
  final String? badge;
  final bool highlighted;
  final bool isCurrentPlan;
  final String ctaLabel;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final borderWidth = highlighted ? 2.0 : 1.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(highlighted ? 40 : 16),
            blurRadius: highlighted ? 22 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: highlighted
            ? Color.lerp(Colors.white, accent, 0.06)
            : Colors.white.withAlpha(250),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: highlighted ? accent.withAlpha(140) : accent.withAlpha(45),
            width: borderWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(28),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accent, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (badge != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: accent,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    price,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ],
              ),
              if (priceHighlight != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0).withAlpha(240),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFFB74D).withAlpha(120),
                    ),
                  ),
                  child: Text(
                    priceHighlight!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color.lerp(accent, const Color(0xFFE65100), 0.35),
                    ),
                  ),
                ),
              ],
              if (priceHint != null) ...[
                const SizedBox(height: 4),
                Text(
                  priceHint!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent.withAlpha(200),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ...features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _FeatureRow(text: f, accent: accent),
                ),
              ),
              const SizedBox(height: 12),
              if (isCurrentPlan && onPressed == null)
                OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    disabledForegroundColor: accent,
                    side: BorderSide(color: accent.withAlpha(100)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(ctaLabel),
                )
              else
                FilledButton(
                  onPressed: busy ? null : onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          ctaLabel,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_rounded, size: 16, color: accent.withAlpha(200)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    final trustItems = S.of(context).plusTrustStripItems;
    final items = [
      (Icons.verified_user_rounded, trustItems[0]),
      (Icons.family_restroom_rounded, trustItems[1]),
      (Icons.star_rounded, trustItems[2]),
      (Icons.favorite_rounded, trustItems[3]),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryPurple.withAlpha(30)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Icon(items[i].$1, size: 20, color: AppTheme.primaryPurple),
                  const SizedBox(height: 5),
                  Text(
                    items[i].$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (i < items.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
