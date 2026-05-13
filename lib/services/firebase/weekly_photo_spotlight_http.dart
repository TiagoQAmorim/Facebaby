import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../firebase_options.dart';

/// Fallback HTTP para o documento `spotlight_current` — contorna Firestore Rules.
///
/// Endpoint em `functions/index.js` (`inspectSpotlight`). Timestamps vêm como ISO no JSON.
///
/// URLs tentadas por ordem:
/// 1. `INSPECT_SPOTLIGHT_URL` (dart-define), se definida
/// 2. `INSPECT_SPOTLIGHT_ALT_URL` (segundo host, ex. `*.run.app` após deploy Gen2)
/// 3. `https://southamerica-east1-<projectId>.cloudfunctions.net/inspectSpotlight`
class WeeklyPhotoSpotlightHttp {
  WeeklyPhotoSpotlightHttp._();

  static const String _region = 'southamerica-east1';

  static List<Uri> _inspectUris() {
    const primary = String.fromEnvironment('INSPECT_SPOTLIGHT_URL');
    const alt = String.fromEnvironment('INSPECT_SPOTLIGHT_ALT_URL');
    final pid = DefaultFirebaseOptions.currentPlatform.projectId;
    final out = <Uri>[];
    if (primary.isNotEmpty) out.add(Uri.parse(primary));
    if (alt.isNotEmpty) out.add(Uri.parse(alt));
    out.add(Uri.parse('https://$_region-$pid.cloudfunctions.net/inspectSpotlight'));
    return out;
  }

  /// Devolve o `data` cru do documento (`{...campos}`) ou `null` se não existir / falhar.
  static Future<Map<String, dynamic>?> fetch() async {
    Object? lastErr;
    for (final uri in _inspectUris()) {
      try {
        final resp = await http.get(uri).timeout(const Duration(seconds: 8));
        if (resp.statusCode != 200) {
          debugPrint('WeeklyPhotoSpotlightHttp: $uri status ${resp.statusCode}: ${resp.body}');
          continue;
        }
        final body = json.decode(resp.body) as Map<String, dynamic>;
        if (body['exists'] != true) {
          debugPrint('WeeklyPhotoSpotlightHttp: $uri exists=${body['exists']}');
          continue;
        }
        final data = body['data'];
        if (data is! Map) return null;
        return Map<String, dynamic>.from(data);
      } catch (e, st) {
        lastErr = e;
        debugPrint('WeeklyPhotoSpotlightHttp.fetch $uri failed: $e\n$st');
      }
    }
    if (lastErr != null) {
      debugPrint('WeeklyPhotoSpotlightHttp.fetch: all URIs failed (last: $lastErr)');
    }
    return null;
  }
}
