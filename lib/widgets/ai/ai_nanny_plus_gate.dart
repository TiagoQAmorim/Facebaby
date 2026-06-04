import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../pages/premium/premium_paywall_screen.dart';
import '../../theme/app_theme.dart';

/// Ecrã bloqueado da IA Babá para utilizadores no plano free.
class AiNannyPlusGate extends StatelessWidget {
  const AiNannyPlusGate({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Image.asset(
                'assets/ai/ia_baba_button.png',
                width: 88,
                height: 88,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.auto_awesome_rounded,
                  size: 72,
                  color: Color(0xFF8E24AA),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                s.aiNannyPremiumTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4A148C),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s.aiNannyPremiumBody,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => openPremiumPaywall(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryPink,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    s.aiNannyPremiumCta,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
