import '../../controllers/memory_controller.dart';
import '../../models/baby_memory.dart';
import 'premium_constants.dart';
import 'premium_service.dart';

/// Regras **Free vs pago (Plus)**.
///
/// Plano **free**: rotinas, registos e memórias básicas — **sem qualquer IA**.
/// Plano **pago**: mensal, anual ou vitalício ([PremiumService.isPremium]).
abstract final class FeatureAccess {
  FeatureAccess._();

  static bool get _premium => PremiumService.instance.isPremium;

  /// Plano pago ativo (mensal, anual ou legado vitalício).
  static bool get hasPaidPlan => _premium;

  /// IA Babá, insights, avisos inteligentes, guias Família (homilia/horóscopo), etc.
  static bool get canUseAnyAi => _premium;

  static bool get canExportPdf => _premium;
  static bool get canExportBadges => _premium;
  static bool get canGenerateMemoryBook => _premium;
  static bool get canUsePremiumAlbumThemes => _premium;
  static bool get canUseCloudBackup => _premium;
  static bool get canUseAdvancedAlerts => _premium;

  static bool get canOpenAdvancedReports => _premium;

  /// IA Babá 24h (chat).
  static bool get canUseAiNanny => _premium;

  /// Horóscopo familiar diário gerado por IA.
  static bool get canUseAiFamilyHoroscope => _premium;

  /// Homilia diária (calendário litúrgico cristão) gerada por IA.
  static bool get canUseAiFamilyHomily => _premium;

  /// Textos de signo solar (pai, mãe, bebê) na árvore Família.
  static bool get canViewFamilyZodiac => _premium;

  /// Estimativa de altura adulta na árvore Família.
  static bool get canViewFamilyHeightEstimate => _premium;

  static bool memoryHasBody(BabyMemory? m) {
    if (m == null) return false;
    final photo = m.photoB64?.trim().isNotEmpty == true || m.photoUrl?.trim().isNotEmpty == true;
    final text = (m.description ?? '').trim().isNotEmpty || (m.motherNotes ?? '').trim().isNotEmpty;
    return photo || text;
  }

  /// Abrir editor para novo selo (+ ou badge vazio) sem Premium.
  static bool canOpenNewMemoryMoment({
    required MemoryController controller,
    String? badgeId,
  }) {
    if (_premium) return true;
    if (badgeId != null) {
      final existing = controller.byBadge[badgeId];
      if (memoryHasBody(existing)) return true;
    }
    return filledMemoryCount(controller) < PremiumConstants.freeMemoryMomentsMax;
  }

  static bool canSaveNewMemoryMoment({
    required MemoryController controller,
    required String badgeId,
    required bool isEditing,
  }) {
    if (_premium) return true;
    if (isEditing) return true;
    return canOpenNewMemoryMoment(controller: controller, badgeId: badgeId);
  }

  static int filledMemoryCount(MemoryController controller) {
    var n = 0;
    for (final m in controller.byBadge.values) {
      if (memoryHasBody(m)) n++;
    }
    return n;
  }
}
