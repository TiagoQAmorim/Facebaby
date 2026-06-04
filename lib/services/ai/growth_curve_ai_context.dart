import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../growth_curve_alert_service.dart';
import '../home_prefs.dart';

/// Bloco de contexto para a IA Babá mencionar peso/altura fora da curva.
abstract final class GrowthCurveAiContext {
  GrowthCurveAiContext._();

  /// Texto enviado à Cloud Function `askAiNanny` (null = sem alerta ativo).
  static Future<String?> blockForCurrentBaby({required S strings}) async {
    if (!HomePrefs.growthHealthAlertsEnabled.value) return null;

    final babyId = CurrentBabyController.instance.currentBabyId;
    final row = CurrentBabyController.instance.currentBabyRow;
    if (babyId == null || row == null) return null;

    final birthRaw = (row['birth_date'] as String?)?.trim() ?? '';
    final birthDate =
        birthRaw.isEmpty ? null : DateTime.tryParse(birthRaw);
    if (birthDate == null) return null;

    var name = (row['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) name = strings.baby;
    final sex = (row['sex'] as String?)?.trim();

    final items = await const GrowthCurveAlertService().outOfBandForBaby(
      babyId: babyId,
      babySex: sex,
      birthDate: birthDate,
    );
    if (items.isEmpty) return null;

    final lines = <String>[
      strings.aiNannyGrowthCurveContextHeader,
      '',
    ];
    for (final item in items) {
      lines.add(
        '• ${GrowthCurveAlertService.bubbleText(item: item, babyName: name, strings: strings)}',
      );
    }
    lines.add('');
    lines.add(strings.aiNannyGrowthCurveContextFooter);
    return lines.join('\n');
  }
}
