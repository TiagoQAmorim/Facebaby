// ignore_for_file: prefer_const_constructors, prefer_const_declarations

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

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen>
    with WidgetsBindingObserver {
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
            SnackBar(
                content: Text(S.of(context).plusPurchaseSkuNotFoundSnack(
                    PremiumConstants.productIdLifetime))),
          );
          break;
        case PurchaseLifetimeResult.billingLaunchFailed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context).plusPurchaseBillingLaunchFailedSnack),
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
    final purple =
        Color.lerp(AppTheme.primaryPurple, AppTheme.primaryPink, 0.35)!;

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
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
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
                                padding:
                                    const EdgeInsets.fromLTRB(18, 10, 18, 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(150),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(170),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: purple.withAlpha(40),
                                      blurRadius: 28,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/onboarding/logo.png',
                                  width: 188,
                                  height: 66,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
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
                            Text(
                              'Cada plano foi pensado para\napoiar você em cada fase.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 19,
                                height: 1.25,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _PlansComparison(
                              price: svc.formattedLocalizedPrice,
                              busy: _busy,
                              premiumActive: premium,
                              onPurchase: _purchase,
                            ),
                            const SizedBox(height: 18),
                            const _TrustStrip(),
                            const SizedBox(height: 14),
                            Text(
                              premium
                                  ? 'Seu Premium está ativo. Você pode conferir os planos a qualquer momento.'
                                  : 'Compra 100% segura. Você pode cancelar quando quiser.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: AppTheme.textMuted.withAlpha(220),
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!premium)
                      Material(
                        color: AppTheme.background,
                        elevation: 0,
                        child: Padding(
                          padding:
                              EdgeInsets.fromLTRB(22, 8, 22, 12 + bottomInset),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (svc.storeAvailable &&
                                  svc.lifetimeProduct == null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    S.of(context).plusPaywallSkuMissingHint(
                                        PremiumConstants.productIdLifetime),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              TextButton(
                                onPressed: _busy ? null : _restore,
                                child: Text(
                                  s.plusCtaRestore,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: purple),
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
                                      fontWeight: FontWeight.w700),
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

class _PlansComparison extends StatelessWidget {
  const _PlansComparison({
    required this.price,
    required this.busy,
    required this.premiumActive,
    required this.onPurchase,
  });

  final String price;
  final bool busy;
  final bool premiumActive;
  final Future<void> Function() onPurchase;

  @override
  Widget build(BuildContext context) {
    final premiumPink =
        Color.lerp(AppTheme.primaryPink, AppTheme.primaryPurple, 0.18)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FreePlanStrip(),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PlanCard(
                title: 'Premium',
                subtitle: 'Tudo para cuidar e\nacompanhar do melhor jeito',
                icon: Icons.workspace_premium_rounded,
                accent: premiumPink,
                highlighted: true,
                badge: 'Mais escolhido',
                features: const [
                  'Tudo do plano Gratuito',
                  'Relatórios completos do bebê',
                  'Relatório para o pediatra (Útil para compartilhar com seu Pediatra)',
                  'Descrição dos Signos',
                  'Mensagens bíblicas diárias',
                  'Análises e insights do desenvolvimento',
                  'Conteúdos e dicas exclusivas',
                  'Suporte prioritário',
                ],
                price: price,
                priceSub: premiumActive ? 'ativo agora' : 'compra segura',
                buttonLabel: premiumActive ? 'Plano atual' : 'Quero Premium',
                outlinedButton: premiumActive,
                busy: busy,
                onPressed: premiumActive || busy ? null : onPurchase,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PlanCard(
                title: 'IA Babá',
                subtitle: 'Assistente inteligente\npara o dia a dia',
                icon: Icons.smart_toy_rounded,
                accent: AppTheme.primaryPurple,
                badge: 'Em breve',
                features: const [
                  'Tudo do plano Premium',
                  'IA Babá 24h com você',
                  'Respostas inteligentes',
                  'Orientações personalizadas',
                  'Alertas preditivos',
                  'Rotinas personalizadas',
                  'Conteúdos gerados pela IA',
                ],
                price: 'Em breve',
                priceSub: 'Fique ligada!',
                buttonLabel: 'Quero ser avisado',
                outlinedButton: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FreePlanStrip extends StatelessWidget {
  const _FreePlanStrip();

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.primaryPurple;
    final features = const [
      'Cadastros básicos',
      'Registro diário',
      'Agendas e lembretes',
      'Peso e altura',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(246),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withAlpha(36)),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.air_rounded, size: 42, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gratuito',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Comece sua jornada com o essencial',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final feature in features)
                      _MiniPlanPill(text: feature, accent: accent),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'R\$ 0,00',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Plano atual',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniPlanPill extends StatelessWidget {
  const _MiniPlanPill({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.features,
    required this.price,
    required this.priceSub,
    required this.buttonLabel,
    this.highlighted = false,
    this.outlinedButton = false,
    this.badge,
    this.busy = false,
    this.onPressed,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<String> features;
  final String price;
  final String priceSub;
  final String buttonLabel;
  final bool highlighted;
  final bool outlinedButton;
  final String? badge;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        highlighted ? accent.withAlpha(115) : Colors.black.withAlpha(18);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: highlighted ? accent.withAlpha(12) : Colors.white.withAlpha(246),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: highlighted ? 1.4 : 1),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(highlighted ? 26 : 12),
            blurRadius: highlighted ? 20 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (badge != null)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 48, color: accent),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: highlighted ? accent : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              for (final feature in features) ...[
                _PlanFeature(text: feature, accent: accent),
                const SizedBox(height: 8),
              ],
              const Spacer(),
              const SizedBox(height: 12),
              Text(
                price,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                priceSub,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              outlinedButton
                  ? OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        disabledForegroundColor: accent,
                        side: BorderSide(color: accent.withAlpha(120)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(buttonLabel),
                    )
                  : FilledButton.icon(
                      onPressed: onPressed,
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.star_rounded, size: 18),
                      label: Text(buttonLabel),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanFeature extends StatelessWidget {
  const _PlanFeature({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_rounded,
            size: 14, color: accent.withAlpha(170)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 10.2,
              height: 1.25,
              fontWeight: FontWeight.w700,
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
    final items = const [
      (Icons.verified_user_rounded, 'Seus dados\nsempre seguros'),
      (Icons.family_restroom_rounded, 'Feito com amor\npara famílias'),
      (Icons.star_rounded, 'Conteúdos confiáveis\ne atualizados'),
      (Icons.favorite_rounded, 'Apoio em cada\nmomento'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EA).withAlpha(230),
        borderRadius: BorderRadius.circular(18),
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
