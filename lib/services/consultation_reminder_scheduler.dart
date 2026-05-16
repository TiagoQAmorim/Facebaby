import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_locale.dart';
import '../i18n/app_i18n.dart';
import '../models/consultation_record.dart';
import 'app_database.dart';
import 'local_notifications_service.dart';

/// Lembretes locais: **dia anterior à consulta às 06:00** (hora local).
class ConsultationReminderScheduler {
  ConsultationReminderScheduler._();

  static final ConsultationReminderScheduler instance = ConsultationReminderScheduler._();

  static const int _notificationIdBase = 600000;

  static const String _prefsAllIdsKeyPrefix = 'consult_remind_all_ids_v2_b';
  static const String _prefsSchedSigKeyPrefix = 'consult_remind_sig_v3_alarm_clock_b';

  static int notificationId(int consultationId) => _notificationIdBase + consultationId;

  /// Payload para [NotificationNav]: `nav_consultation:<id>`.
  static String payloadFor(int consultationId) => 'nav_consultation:$consultationId';

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

  /// Mesma regra visual que a Home (`_consultationForBanner`): mostrar no **dia da consulta**,
  /// das **06:00** até à hora da consulta (ainda futura).
  static bool shouldShowDayOfBanner(ConsultationRecord c, DateTime now) {
    if (!c.occurredAt.isAfter(now)) return false;
    final start = DateTime(c.occurredAt.year, c.occurredAt.month, c.occurredAt.day, 6);
    if (now.isBefore(start)) return false;
    return DateTime(now.year, now.month, now.day) ==
        DateTime(c.occurredAt.year, c.occurredAt.month, c.occurredAt.day);
  }

  /// Dia civil anterior ao dia da consulta, às 06:00 local (relativo a [occurredLocal]).
  static DateTime reminderLocalDayBeforeSix(DateTime occurredLocal) {
    final consultDay = DateTime(occurredLocal.year, occurredLocal.month, occurredLocal.day);
    final prevDay = consultDay.subtract(const Duration(days: 1));
    return DateTime(prevDay.year, prevDay.month, prevDay.day, 6, 0);
  }

  /// Estado que determina IDs de alarme já agendados (evita reagendar a cada minuto no [ReminderMonitor]).
  static String _scheduleSignature(DateTime now, List<Map<String, Object?>> rows) {
    final parts = <String>[];
    for (final row in rows) {
      final r = ConsultationRecord.fromRow(row);
      if (!r.occurredAt.isAfter(now)) continue;
      final when = reminderLocalDayBeforeSix(r.occurredAt);
      if (!when.isAfter(now)) continue;
      parts.add('${r.id}|${when.toIso8601String()}|${r.title.trim()}');
    }
    parts.sort();
    final lang = kAppLanguage.lang.name;
    return '$lang:${parts.join(';')}';
  }

  /// Cancela e volta a agendar todos os lembretes futuros para este bebê (após CRUD ou ao retomar o app).
  ///
  /// Se não mudou nem a lista de consultas nem o instante/lembrete, **não** volta a chamar ao SO —
  /// evita múltiplas linhas «Agendada» na inbox e cancel/reagenda inútil (Android/iOS).
  Future<void> rescheduleForBaby(int babyId) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final idsKey = '$_prefsAllIdsKeyPrefix$babyId';
      final sigKey = '$_prefsSchedSigKeyPrefix$babyId';

      final rows = await AppDatabase.instance.listConsultations(babyId: babyId);
      final now = DateTime.now();

      final currentIds = <int>{
        for (final row in rows) ConsultationRecord.fromRow(row).id,
      };
      final prevIds = _parseIdSet(prefs.getString(idsKey));
      for (final removed in prevIds.difference(currentIds)) {
        await LocalNotificationsService.instance.cancelNotificationIds([notificationId(removed)]);
      }
      await prefs.setString(idsKey, currentIds.isEmpty ? '' : currentIds.map((e) => '$e').join(','));

      final nextSig = _scheduleSignature(now, rows);
      if (prefs.getString(sigKey) == nextSig) {
        return;
      }

      final strings = S(kAppLanguage.lang);
      for (final row in rows) {
        final r = ConsultationRecord.fromRow(row);
        final nid = notificationId(r.id);
        await LocalNotificationsService.instance.cancelNotificationIds([nid]);
        if (!r.occurredAt.isAfter(now)) continue;
        final when = reminderLocalDayBeforeSix(r.occurredAt);
        if (!when.isAfter(now)) continue;
        final whenLabel =
            '${r.occurredAt.day.toString().padLeft(2, '0')}/${r.occurredAt.month.toString().padLeft(2, '0')} '
            '${r.occurredAt.hour.toString().padLeft(2, '0')}:${r.occurredAt.minute.toString().padLeft(2, '0')}';
        final ok = await LocalNotificationsService.instance.scheduleZoned(
          id: nid,
          title: strings.consultationReminderNotifTitle,
          body: strings.consultationReminderNotifBody(r.title, whenLabel),
          whenLocal: when,
          payload: payloadFor(r.id),
        );
        if (!ok) {
          debugPrint('ConsultationReminderScheduler: scheduleZoned failed for consultation ${r.id}');
        }
      }

      await prefs.setString(sigKey, nextSig);
    } catch (e, st) {
      debugPrint('ConsultationReminderScheduler: $e\n$st');
    }
  }
}
