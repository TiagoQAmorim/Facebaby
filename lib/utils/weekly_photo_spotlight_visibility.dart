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
  ///   - `winner_photo_url` HTTPS não vazio e não reconhecido como stock/demo (a não ser
  ///     [WeeklyPhotoSpotlightConfig.kAllowStockSpotlightPhotoUrls] ou
  ///     `allow_stock_winner_photo: true` no mesmo documento)
  ///   - `winner_badge_title` não vazio
  ///   - `winner_public_memory_id` não vazio; `winner_user_id` obrigatório salvo foto em
  ///     Firebase Storage / Google user content (fallback quando o sorteio só tinha `owner_uid`).
  static bool shouldShowForBanner(Map<String, dynamic>? d, DateTime now) {
    if (d == null) return false;
    final statusRaw = d['status'];
    final statusStr = statusRaw == null ? null : '$statusRaw'.trim().toLowerCase();
    if (statusStr != null && statusStr.isNotEmpty && statusStr != 'active') return false;

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

  /// Campo Firestore / JSON que pode vir como [String] ou outro tipo.
  static String? _nonEmptyStringField(Object? v) {
    if (v == null) return null;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    final t = '$v'.trim();
    return t.isEmpty ? null : t;
  }

  static bool _hasMinimumWinnerData(Map<String, dynamic> d) {
    final photoUrl = _nonEmptyStringField(d['winner_photo_url']) ??
        _nonEmptyStringField(d['winnerPhotoUrl']);
    if (photoUrl == null) return false;
    if (!photoUrl.toLowerCase().startsWith('https://')) return false;
    final allowStockUrl = WeeklyPhotoSpotlightConfig.kAllowStockSpotlightPhotoUrls ||
        d['allow_stock_winner_photo'] == true ||
        d['allowStockWinnerPhoto'] == true;
    if (!allowStockUrl && WeeklyPhotoSpotlightUrls.looksLikeDemoOrPlaceholder(photoUrl)) {
      return false;
    }

    final badgeTitle = _nonEmptyStringField(d['winner_badge_title']) ??
        _nonEmptyStringField(d['winnerBadgeTitle']);
    if (badgeTitle == null) return false;

    // Só destaque ligado a memória pública + dono (evita seeds só com URL stock). Se o backend
    // gravou só `owner_uid` no doc público, `winner_user_id` pode faltar — aceitar foto Firebase
    // Storage + id da memória pública.
    final memoryId = _nonEmptyStringField(d['winner_public_memory_id']) ??
        _nonEmptyStringField(d['winnerPublicMemoryId']);
    if (memoryId == null) return false;

    final hasWinnerUser = (_nonEmptyStringField(d['winner_user_id']) ??
            _nonEmptyStringField(d['winnerUserId'])) !=
        null;
    if (!hasWinnerUser) {
      final u = photoUrl.toLowerCase();
      final trustStorage = u.contains('firebasestorage.googleapis.com') ||
          u.contains('googleusercontent.com');
      if (!trustStorage) return false;
    }

    return true;
  }
}
