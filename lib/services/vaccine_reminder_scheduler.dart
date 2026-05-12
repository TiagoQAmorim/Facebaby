import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_locale.dart';
import '../i18n/app_i18n.dart';
import '../models/vaccine_record.dart';
import 'app_database.dart';
import 'local_notifications_service.dart';

/// Lembretes locais: no **dia da vacina** às 09:00 (hora local).
///
/// Considera a data `next_due_at` (próxima dose). `applied_at` é histórico (geralmente passado).
class VaccineReminderScheduler {
  VaccineReminderScheduler._();

  static final VaccineReminderScheduler instance = VaccineReminderScheduler._();

  static const int _notificationIdBase = 700000;
  static const String _prefsAllIdsKeyPrefix = 'vacc_remind_all_ids_v1_b';
  static const String _prefsSchedSigKeyPrefix = 'vacc_remind_sig_v1_b';

  static int notificationId(int vaccineId) => _notificationIdBase + vaccineId;

  /// Payload para [NotificationNav]: abre detalhe desta vacina (`nav_vaccine:<id>`).
  static String payloadFor(int vaccineId) => 'nav_vaccine:$vaccineId';

  static Set<int> _parseIdSet(String? raw) {
    final out = <int>{};
    if (raw == null || raw.isEmpty) return out;
    for (final piece in raw.split(',')) {
      final t = piece.trim();
      if (t.isEmpty) continue;
      final v = int.tryParse(t);
      if (v != null) out.add(v);
    }
    return out;
  }

  static DateTime reminderLocalNine(DateTime dueLocal) {
    final d = DateTime(dueLocal.year, dueLocal.month, dueLocal.day);
    return DateTime(d.year, d.month, d.day, 9, 0);
  }

  static String _scheduleSignature(DateTime now, List<Map<String, Object?>> rows) {
    final parts = <String>[];
    for (final row in rows) {
      final r = VaccineRecord.fromRow(row);
      final due = r.nextDueAt;
      if (due == null) continue;
      if (!due.isAfter(now)) continue;
      final when = reminderLocalNine(due);
      if (!when.isAfter(now)) continue;
      parts.add('${r.id}|${when.toIso8601String()}|${r.name.trim()}');
    }
    parts.sort();
    final lang = kAppLanguage.lang.name;
    return '$lang:${parts.join(';')}';
  }

  /// Reagenda todos os lembretes futuros de vacinas para este bebê.
  Future<void> rescheduleForBaby(int babyId) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final idsKey = '$_prefsAllIdsKeyPrefix$babyId';
      final sigKey = '$_prefsSchedSigKeyPrefix$babyId';

      final rows = await AppDatabase.instance.listVaccines(babyId: babyId);
      final now = DateTime.now();

      final currentIds = <int>{
        for (final row in rows) VaccineRecord.fromRow(row).id,
      };
      final prevIds = _parseIdSet(prefs.getString(idsKey));
      for (final removed in prevIds.difference(currentIds)) {
        await LocalNotificationsService.instance.cancelNotificationIds([notificationId(removed)]);
      }
      await prefs.setString(idsKey, currentIds.isEmpty ? '' : currentIds.map((e) => '$e').join(','));

      final nextSig = _scheduleSignature(now, rows);
      if (prefs.getString(sigKey) == nextSig) return;

      final strings = S(kAppLanguage.lang);
      for (final row in rows) {
        final r = VaccineRecord.fromRow(row);
        final nid = notificationId(r.id);
        await LocalNotificationsService.instance.cancelNotificationIds([nid]);
        final due = r.nextDueAt;
        if (due == null) continue;
        if (!due.isAfter(now)) continue;
        final when = reminderLocalNine(due);
        if (!when.isAfter(now)) continue;
        final ok = await LocalNotificationsService.instance.scheduleZoned(
          id: nid,
          title: strings.vaccineReminderNotifTitle,
          body: strings.vaccineReminderNotifBody(r.name),
          whenLocal: when,
          payload: payloadFor(r.id),
        );
        if (!ok) {
          debugPrint('VaccineReminderScheduler: scheduleZoned failed for vaccine ${r.id}');
        }
      }

      await prefs.setString(sigKey, nextSig);
    } catch (e, st) {
      debugPrint('VaccineReminderScheduler: $e\n$st');
    }
  }
}

