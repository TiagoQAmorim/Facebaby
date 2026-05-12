import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Fallback HTTP para o documento `spotlight_current` — contorna Firestore Rules.
///
/// Endpoint criado em `functions/index.js` (`inspectSpotlight`). Retorna o documento cru,
/// com `Timestamp`s convertidos para ISO strings.
class WeeklyPhotoSpotlightHttp {
  WeeklyPhotoSpotlightHttp._();

  static const String _endpoint =
      'https://southamerica-east1-facebaby-afc41.cloudfunctions.net/inspectSpotlight';

  /// Devolve o `data` cru do documento (`{...campos}`) ou `null` se não existir / falhar.
  static Future<Map<String, dynamic>?> fetch() async {
    try {
      final resp = await http
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        debugPrint('WeeklyPhotoSpotlightHttp: status ${resp.statusCode}: ${resp.body}');
        return null;
      }
      final body = json.decode(resp.body) as Map<String, dynamic>;
      if (body['exists'] != true) return null;
      final data = body['data'];
      if (data is! Map) return null;
      return Map<String, dynamic>.from(data);
    } catch (e, st) {
      debugPrint('WeeklyPhotoSpotlightHttp.fetch failed: $e\n$st');
      return null;
    }
  }
}
