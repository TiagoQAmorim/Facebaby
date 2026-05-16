import '../../controllers/memory_controller.dart';
import '../../models/baby_memory.dart';
import 'premium_constants.dart';
import 'premium_service.dart';

/// Regras **Free vs Premium** (o que é grátis, o que exige Premium).
///
/// O modelo de pagamento passou de assinatura mensal para **compra única vitalícia**;
/// as flags e limites abaixo **mantêm-se** — só mudou como o utilizador desbloqueia
/// o Premium ([PremiumService] / IAP `facebaby_premium`).
abstract final class FeatureAccess {
  FeatureAccess._();

  static bool get _premium => PremiumService.instance.isPremium;

  static bool get canExportPdf => _premium;
  static bool get canExportBadges => _premium;
  static bool get canGenerateMemoryBook => _premium;
  static bool get canUsePremiumAlbumThemes => _premium;
  static bool get canUseCloudBackup => _premium;
  static bool get canUseAdvancedAlerts => _premium;

  static bool get canOpenAdvancedReports => _premium;

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

  static bool canSaveNewMemoryMoment({
    required MemoryController controller,
    required String badgeId,
    required bool isEditing,
  }) {
    if (_premium) return true;
    if (isEditing) return true;
    final existing = controller.byBadge[badgeId];
    if (memoryHasBody(existing)) return true;

    var filled = 0;
    for (final m in controller.byBadge.values) {
      if (memoryHasBody(m)) filled++;
    }
    return filled < PremiumConstants.freeMemoryMomentsMax;
  }

  static int filledMemoryCount(MemoryController controller) {
    var n = 0;
    for (final m in controller.byBadge.values) {
      if (memoryHasBody(m)) n++;
    }
    return n;
  }
}
