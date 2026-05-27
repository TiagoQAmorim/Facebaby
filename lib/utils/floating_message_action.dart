import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Validação e abertura de links externos do balão flutuante.
class FloatingMessageAction {
  FloatingMessageAction._();

  static bool isValidHttpsUrl(String? raw) {
    return httpsUri(raw) != null;
  }

  static bool isValidImageUrl(String? raw) {
    final u = raw?.trim() ?? '';
    if (u.isEmpty) return false;
    if (!isValidHttpsUrl(u)) return false;
    final lower = u.toLowerCase();
    if (RegExp(r'\.(png|jpe?g|webp|gif)(\?|$)', caseSensitive: false)
        .hasMatch(lower)) {
      return true;
    }
    return lower.contains('firebasestorage.googleapis.com') ||
        lower.contains('googleusercontent.com');
  }

  /// Normaliza para URI https (aceita `www.site.com` sem esquema).
  static Uri? httpsUri(String? raw) {
    var u = raw?.trim() ?? '';
    if (u.isEmpty) return null;
    if (!u.contains('://')) {
      u = 'https://$u';
    }
    final uri = Uri.tryParse(u);
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme != 'https') return null;
    if (uri.host.trim().isEmpty) return null;
    return uri;
  }

  /// Abre [actionUrl] (https). Retorna `false` se falhar.
  ///
  /// No Android 11+, [canLaunchUrl] pode retornar `false` mesmo com URL válida
  /// se o manifest não declarar `<queries>` para https — tentamos [launchUrl]
  /// mesmo assim.
  static Future<bool> openExternalUrl(String? actionUrl) async {
    final uri = httpsUri(actionUrl);
    if (uri == null) {
      debugPrint(
        'FloatingMessageAction: URL inválida (https obrigatório): '
        '${actionUrl?.trim() ?? '(vazio)'}',
      );
      return false;
    }
    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return true;
      }

      debugPrint(
        'FloatingMessageAction: canLaunch=$canLaunch, tentando launch direto: $uri',
      );
      final direct = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (direct) return true;

      final platform = await launchUrl(uri, mode: LaunchMode.platformDefault);
      return platform;
    } catch (e, st) {
      debugPrint('FloatingMessageAction.openExternalUrl: $e\n$st');
      return false;
    }
  }
}
