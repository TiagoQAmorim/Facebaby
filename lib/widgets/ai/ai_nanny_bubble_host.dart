import 'package:flutter/material.dart';

import '../../controllers/current_baby_controller.dart';
import '../../services/premium/feature_access.dart';
import '../../services/premium/premium_service.dart';
import '../../i18n/app_i18n.dart';
import 'ai_floating_insights_host.dart';

/// Balão da IA Babá na Home: resumo de ontem, curiosidades, insights e avisos.
class AiNannyBubbleHost extends StatelessWidget {
  const AiNannyBubbleHost({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        PremiumService.instance,
        CurrentBabyController.instance,
      ]),
      builder: (context, _) {
        if (!FeatureAccess.canUseAnyAi) return const SizedBox.shrink();
        final current = CurrentBabyController.instance;
        final row = current.currentBabyRow;
        final babyId = current.currentBabyId;
        final s = S.of(context);

        var name = (row?['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) name = s.baby;

        final sex = (row?['sex'] as String?)?.trim();
        final birthRaw = (row?['birth_date'] as String?)?.trim() ?? '';
        final birthDate = birthRaw.isEmpty ? null : DateTime.tryParse(birthRaw);

        return AiFloatingInsightsHost(
          babyId: babyId,
          babyName: name,
          babySex: sex,
          birthDate: birthDate,
        );
      },
    );
  }
}
