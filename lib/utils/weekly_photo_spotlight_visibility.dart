import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/weekly_photo_spotlight_config.dart';
import 'weekly_photo_schedule.dart';
import 'weekly_photo_spotlight_urls.dart';

/// Quando o banner da Home / modal de parabéns deve considerar o destaque “visível”, além da
/// janela semanal em [WeeklyPhotoSchedule.isWithinSpotlightDisplay].
class WeeklyPhotoSpotlightVisibility {
  WeeklyPhotoSpotlightVisibility._();

  static DateTime? tryFirestoreInstant(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.round());
    return null;
  }

  /// `spotlight_current` com `status` activo, dados mínimos coerentes e dentro da janela
  /// **ou** com bypass do servidor / emergência client-side.
  ///
  /// Mínimos exigidos para mostrar o banner — protege contra seeds de teste ficarem
  /// visíveis com cartão vazio:
  ///   - `winner_photo_url` HTTPS não vazio e não reconhecido como stock/demo
  ///   - `winner_badge_title` não vazio
  ///   - `winner_public_memory_id` e `winner_user_id` (memória pública real no Firestore)
  static bool shouldShowForBanner(Map<String, dynamic>? d, DateTime now) {
    if (d == null) return false;
    final status = d['status'] as String?;
    if (status != null && status != 'active') return false;

    if (!_hasMinimumWinnerData(d)) return false;

    final bypassServer = d['bypass_display_window'] == true || d['bypassDisplayWindow'] == true;
    if (bypassServer || WeeklyPhotoSpotlightConfig.kEmergencyBypassDisplayWindow) return true;

    final drawAt = tryFirestoreInstant(d['draw_at'] ?? d['drawAt']);
    final until = tryFirestoreInstant(d['display_until'] ?? d['displayUntil']);
    if (drawAt == null || until == null) return false;
    return WeeklyPhotoSchedule.isWithinSpotlightDisplay(
      now: now,
      drawAt: drawAt,
      displayUntil: until,
    );
  }

  static String? _nonEmpty(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static bool _hasMinimumWinnerData(Map<String, dynamic> d) {
    final photoUrl =
        _nonEmpty(d['winner_photo_url']) ?? _nonEmpty(d['winnerPhotoUrl']);
    if (photoUrl == null) return false;
    if (!photoUrl.toLowerCase().startsWith('https://')) return false;
    if (WeeklyPhotoSpotlightUrls.looksLikeDemoOrPlaceholder(photoUrl)) return false;

    final badgeTitle =
        _nonEmpty(d['winner_badge_title']) ?? _nonEmpty(d['winnerBadgeTitle']);
    if (badgeTitle == null) return false;

    // Só destaque ligado a memória pública + dono (evita seeds manuais só com ?photoUrl= de stock).
    final memoryId =
        _nonEmpty(d['winner_public_memory_id']) ?? _nonEmpty(d['winnerPublicMemoryId']);
    final userId = _nonEmpty(d['winner_user_id']) ?? _nonEmpty(d['winnerUserId']);
    if (memoryId == null || userId == null) return false;

    return true;
  }
}
