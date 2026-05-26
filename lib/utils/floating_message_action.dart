import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Validação e abertura de links externos do balão flutuante.
class FloatingMessageAction {
  FloatingMessageAction._();

  static bool isValidHttpsUrl(String? raw) {
    final u = raw?.trim() ?? '';
    if (u.isEmpty) return false;
    final uri = Uri.tryParse(u.contains('://') ? u : 'https://$u');
    if (uri == null || !uri.hasScheme) return false;
    if (uri.scheme != 'https') return false;
    if (uri.host.trim().isEmpty) return false;
    return true;
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

  static Uri? httpsUri(String? raw) {
    if (!isValidHttpsUrl(raw)) return null;
    final u = raw!.trim();
    return Uri.parse(u.contains('://') ? u : 'https://$u');
  }

  /// Abre [actionUrl] (https). Retorna `false` se falhar.
  static Future<bool> openExternalUrl(String? actionUrl) async {
    final uri = httpsUri(actionUrl);
    if (uri == null) {
      debugPrint('FloatingMessageAction: URL inválida (https obrigatório)');
      return false;
    }
    try {
      if (!await canLaunchUrl(uri)) {
        debugPrint('FloatingMessageAction: canLaunchUrl=false $uri');
        return false;
      }
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return ok;
    } catch (e, st) {
      debugPrint('FloatingMessageAction.openExternalUrl: $e\n$st');
      return false;
    }
  }
}
