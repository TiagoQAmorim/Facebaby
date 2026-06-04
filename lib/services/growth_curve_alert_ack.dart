import 'package:shared_preferences/shared_preferences.dart';

import 'growth_curve_alert_service.dart';

/// Evita repetir alerta de curva no balão/push para a mesma medição.
/// Só volta a alertar quando há novo registro (nova assinatura).
abstract final class GrowthCurveAlertAck {
  GrowthCurveAlertAck._();

  static String _prefsKey(int babyId, String kind) =>
      'facebaby_growth_curve_notified_sig_v1_${babyId}_$kind';

  static String _kindFromSignature(String signature) {
    final i = signature.indexOf('_');
    return i > 0 ? signature.substring(0, i) : signature;
  }

  static Future<String?> lastNotifiedSignature({
    required int babyId,
    required String kind,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey(babyId, kind));
  }

  static Future<bool> shouldNotify({
    required int babyId,
    required String signature,
  }) async {
    final kind = _kindFromSignature(signature);
    final last = await lastNotifiedSignature(babyId: babyId, kind: kind);
    return last != signature;
  }

  static Future<void> markNotified({
    required int babyId,
    required String signature,
  }) async {
    final kind = _kindFromSignature(signature);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(babyId, kind), signature);
  }

  static Future<List<GrowthCurveOutOfBand>> filterPending({
    required int babyId,
    required List<GrowthCurveOutOfBand> items,
  }) async {
    final out = <GrowthCurveOutOfBand>[];
    for (final item in items) {
      if (await shouldNotify(babyId: babyId, signature: item.signature)) {
        out.add(item);
      }
    }
    return out;
  }
}
