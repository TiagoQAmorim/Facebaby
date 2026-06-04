import '../../models/bubble_queue_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fila do balão: sem retroativos para usuários novos; expiração de não vistas.
abstract final class AiBubbleQueueLifecycle {
  AiBubbleQueueLifecycle._();

  static const unseenMaxDays = 3;

  /// Bump ao limpar fila local antiga (testes / migração). Firestore pode elevar mais.
  static const kMinLocalQueueGeneration = 2;

  static const _queueGenKey = 'facebaby_bubble_queue_gen_v1';
  static const _appliedResetKey = 'facebaby_bubble_applied_reset_v1';

  static String _anchorKey(int babyId) => 'facebaby_bubble_anchor_v1_$babyId';
  static String _enqueuedKey(int babyId, String prefsKey) =>
      'facebaby_bubble_enq_${babyId}_$prefsKey';
  static String _seenKey(int babyId, String prefsKey) =>
      'facebaby_bubble_seen_${babyId}_$prefsKey';
  static String _dismissKey(int babyId, String prefsKey) =>
      'facebaby_bubble_dismiss_${babyId}_$prefsKey';

  /// Apaga estado local da fila (enfileirado / visto / dispensado / anchor).
  static Future<void> purgeAllLocalQueueState(SharedPreferences prefs) async {
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('facebaby_bubble_enq_') ||
          key.startsWith('facebaby_bubble_seen_') ||
          key.startsWith('facebaby_bubble_dismiss_') ||
          key.startsWith('facebaby_bubble_anchor_')) {
        await prefs.remove(key);
      }
    }
  }

  /// Sincroniza com `floating_message_settings/global` e bump de geração do app.
  static Future<void> runGlobalResetIfNeeded({
    required SharedPreferences prefs,
    required BubbleQueueSettings settings,
  }) async {
    final targetGen = settings.localQueueGeneration > kMinLocalQueueGeneration
        ? settings.localQueueGeneration
        : kMinLocalQueueGeneration;
    final storedGen = prefs.getInt(_queueGenKey) ?? 0;

    final resetBefore = settings.resetBefore;
    final resetIso = resetBefore?.toUtc().toIso8601String();
    final appliedReset = prefs.getString(_appliedResetKey);

    final needsGenReset = storedGen < targetGen;
    final needsRemoteReset =
        resetIso != null && resetIso.isNotEmpty && appliedReset != resetIso;

    if (!needsGenReset && !needsRemoteReset) return;

    await purgeAllLocalQueueState(prefs);
    await prefs.setInt(_queueGenKey, targetGen);
    if (resetIso != null && resetIso.isNotEmpty) {
      await prefs.setString(_appliedResetKey, resetIso);
    }
  }

  /// Primeiro dia com o balão ativo neste dispositivo (não retroativo).
  static Future<DateTime> ensureAnchorDay({
    required int babyId,
    required SharedPreferences prefs,
  }) async {
    final stored = prefs.getString(_anchorKey(babyId));
    final parsed = stored != null ? DateTime.tryParse(stored) : null;
    if (parsed != null) return _dateOnly(parsed);

    final anchor = _dateOnly(DateTime.now());
    await prefs.setString(_anchorKey(babyId), anchor.toIso8601String());
    return anchor;
  }

  static Future<void> noteEnqueued({
    required int babyId,
    required String prefsKey,
    required SharedPreferences prefs,
  }) async {
    final key = _enqueuedKey(babyId, prefsKey);
    if (prefs.containsKey(key)) return;
    await prefs.setString(key, DateTime.now().toIso8601String());
  }

  static Future<void> markSeen({
    required int babyId,
    required String prefsKey,
    required SharedPreferences prefs,
  }) async {
    await prefs.setBool(_seenKey(babyId, prefsKey), true);
  }

  static Future<void> markDismissed({
    required int babyId,
    required String prefsKey,
    required SharedPreferences prefs,
  }) async {
    await prefs.setBool(_dismissKey(babyId, prefsKey), true);
    await markSeen(babyId: babyId, prefsKey: prefsKey, prefs: prefs);
  }

  /// false = não mostrar (dispensada, expirada ou retroativa).
  static Future<bool> shouldShow({
    required int babyId,
    required String prefsKey,
    required SharedPreferences prefs,
    DateTime? contentDay,
    bool skipRetroactiveCheck = false,
    /// Campanhas do admin: ficam na fila até o utilizador fechar (sem expirar em 3 dias).
    bool persistUntilDismissed = false,
  }) async {
    if (prefs.getBool(_dismissKey(babyId, prefsKey)) ?? false) return false;
    if (persistUntilDismissed) return true;

    final enqueuedRaw = prefs.getString(_enqueuedKey(babyId, prefsKey));
    final enqueued = enqueuedRaw != null ? DateTime.tryParse(enqueuedRaw) : null;
    final seen = prefs.getBool(_seenKey(babyId, prefsKey)) ?? false;
    if (enqueued != null && !seen) {
      if (DateTime.now().difference(enqueued).inDays >= unseenMaxDays) {
        return false;
      }
    }

    if (!skipRetroactiveCheck && contentDay != null) {
      final anchor = await ensureAnchorDay(babyId: babyId, prefs: prefs);
      if (_dateOnly(contentDay).isBefore(anchor)) return false;
    }

    return true;
  }

  static Future<bool> allowsHistoricalMoments({
    required int babyId,
    required SharedPreferences prefs,
    required int minDaysOnApp,
  }) async {
    final anchor = await ensureAnchorDay(babyId: babyId, prefs: prefs);
    return _dateOnly(DateTime.now()).difference(anchor).inDays >= minDaysOnApp;
  }

  static bool calendarDayOnOrAfterAnchor(DateTime day, DateTime anchorDay) =>
      !_dateOnly(day).isBefore(anchorDay);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
