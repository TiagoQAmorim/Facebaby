import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../services/premium/premium_constants.dart';
import '../../services/premium/premium_service.dart';
import '../../theme/app_theme.dart';

/// Abre o ecrã moderno de Premium (compra única).
Future<void> openPremiumPaywall(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => const PremiumPaywallScreen(),
    ),
  );
}

/// Paywall / estado “já és Premium” — compra única vitalícia.
class PremiumPaywallScreen extends StatefulWidget {
  const PremiumPaywallScreen({super.key});

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> with WidgetsBindingObserver {
  bool _busy = false;

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

  Future<void> _purchase() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await PremiumService.instance.purchaseLifetime();
      if (!mounted) return;
      if (PremiumService.instance.isPremium) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).plusWelcomeSnack)),
        );
        return;
      }
      switch (result) {
        case PurchaseLifetimeResult.billingFlowLaunched:
          break;
        case PurchaseLifetimeResult.productNotFoundInStore:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).plusPurchaseSkuNotFoundSnack(PremiumConstants.productIdLifetime))),
          );
          break;
        case PurchaseLifetimeResult.billingLaunchFailed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(S.of(context).plusPurchaseBillingLaunchFailedSnack),
              duration: const Duration(seconds: 8),
            ),
          );
          break;
        case PurchaseLifetimeResult.billingUnavailable:
        case PurchaseLifetimeResult.unsupportedPlatform:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).plusPurchaseUnavailableSnack)),
          );
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).plusPurchaseErrorSnack)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final purple = Color.lerp(AppTheme.primaryPurple, AppTheme.primaryPink, 0.35)!;

    return ListenableBuilder(
      listenable: PremiumService.instance,
      builder: (context, _) {
        final svc = PremiumService.instance;
        final premium = svc.isPremium;

        final bottomInset = MediaQuery.paddingOf(context).bottom;

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
                        Color.lerp(Colors.white, purple, 0.06)!,
                        AppTheme.background,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: purple.withAlpha(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: purple.withAlpha(40),
                                      blurRadius: 28,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.auto_awesome_rounded, size: 42, color: purple),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              s.plusBrandTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                                color: purple,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (premium) ...[
                              Text(
                                s.plusPremiumActiveTitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                s.plusPremiumActiveBody,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextButton(
                                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                                child: Text(
                                  s.plusDoneClose,
                                  style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ] else ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _BadgeChip(label: s.plusLifetimePaymentBadge, accent: purple),
                                  const SizedBox(width: 10),
                                  _BadgeChip(label: s.plusNoMonthlyBadge, accent: AppTheme.secondary),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                s.plusSheetHero,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  height: 1.48,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary.withAlpha(235),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: purple.withAlpha(40)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: purple.withAlpha(22),
                                      blurRadius: 22,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      s.plusSheetPriceLabel,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      svc.formattedLocalizedPrice,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 30,
                                        letterSpacing: -0.8,
                                        color: purple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                s.plusSheetBullets,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.58,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                s.plusSheetFootnote,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, height: 1.35, color: AppTheme.textMuted.withAlpha(220)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!premium)
                      Material(
                        color: AppTheme.background,
                        elevation: 0,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(22, 8, 22, 12 + bottomInset),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (svc.storeAvailable && svc.lifetimeProduct == null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    S.of(context).plusPaywallSkuMissingHint(PremiumConstants.productIdLifetime),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              FilledButton(
                                onPressed: (_busy || !svc.storeAvailable) ? null : _purchase,
                                style: FilledButton.styleFrom(
                                  backgroundColor: purple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: _busy
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            s.plusCtaSubscribe,
                                            textAlign: TextAlign.center,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            svc.formattedLocalizedPrice,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: Colors.white.withAlpha(236),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              TextButton(
                                onPressed: _busy ? null : _restore,
                                child: Text(
                                  s.plusCtaRestore,
                                  style: TextStyle(fontWeight: FontWeight.w800, color: purple),
                                ),
                              ),
                              TextButton(
                                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                                child: Text(
                                  s.plusCtaLater,
                                  style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
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

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withAlpha(22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withAlpha(55)),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, color: accent),
      ),
    );
  }
}
