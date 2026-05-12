import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../app/app_locale.dart';
import '../i18n/app_i18n.dart';
import 'app_database.dart';
import 'notification_nav.dart';
import 'notification_timezone.dart';



class LocalNotificationsService {

  LocalNotificationsService._();

  NotificationDetails _reminderChannelDetails() {
    final s = S(kAppLanguage.lang);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders',
        s.notifChannelRemindersName,
        channelDescription: s.notifChannelRemindersDesc,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  NotificationDetails _growthChannelDetails() {
    final s = S(kAppLanguage.lang);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'growth_alerts',
        s.notifChannelGrowthName,
        channelDescription: s.notifChannelGrowthDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }



  static final LocalNotificationsService instance = LocalNotificationsService._();



  static const _prefsKeyInstallPromptDone = 'facebaby_notif_install_prompt_done_v1';



  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _coreInitialized = false;



  /// Só inicializa o plugin — **não** pede permissão (evita duplicar com [requestPermission]).

  Future<void> ensureCoreInitialized() async {
    if (_coreInitialized || kIsWeb) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const ios = DarwinInitializationSettings();

    const initSettings = InitializationSettings(android: android, iOS: ios);

    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          NotificationNav.scheduleOpen(response.payload);
        },
      );

      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        NotificationNav.scheduleOpen(launch!.notificationResponse?.payload);
      }
      _coreInitialized = true;
    } catch (e, st) {
      debugPrint('LocalNotificationsService.ensureCoreInitialized failed: $e\n$st');
    }
  }



  /// Abre o diálogo do sistema conforme Android 13+ / iOS. Idempotente ao chamar várias vezes.

  Future<void> requestPermission() async {

    if (kIsWeb) return;

    await ensureCoreInitialized();



    try {

      final impl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      await impl?.requestNotificationsPermission();
      // Android 12+: alarmas exatos para horários precisos (sem isto o SO pode só agendar de forma aproximada ou bloquear).
      await impl?.requestExactAlarmsPermission();

    } catch (_) {}



    try {

      final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

      await iosImpl?.requestPermissions(

        alert: true,

        badge: true,

        sound: true,

      );

    } catch (_) {}

  }



  /// Uma vez após instalar / primeira vez que o app chega ao shell principal (usa prefs).

  Future<void> requestPermissionOnceOnFirstLaunch() async {

    if (kIsWeb) return;

    try {

      final prefs = await SharedPreferences.getInstance();

      if (prefs.getBool(_prefsKeyInstallPromptDone) == true) return;

      await requestPermission();

      await prefs.setBool(_prefsKeyInstallPromptDone, true);

    } catch (_) {}

  }



  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await ensureCoreInitialized();
    if (!_coreInitialized) {
      debugPrint('LocalNotificationsService.show($id): plugin not initialized — bailing out.');
      return;
    }
    final details = _reminderChannelDetails();
    try {
      await _plugin.show(id, title, body, details, payload: payload);
    } catch (e, st) {
      debugPrint('LocalNotificationsService.show($id) failed: $e\n$st');
      return;
    }
    // Log da BD em background — uma falha aqui NUNCA pode bloquear o show
    // (já entregue ao SO acima). Veja [_persistNotificationLog].
    unawaited(_persistNotificationLog(
      notifId: id,
      title: title,
      body: body,
      payload: payload,
      kind: 'shown',
      occurredAt: DateTime.now(),
    ));
  }

  Future<void> showGrowthAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await ensureCoreInitialized();
    if (!_coreInitialized) {
      debugPrint('LocalNotificationsService.showGrowthAlert($id): plugin not initialized — bailing out.');
      return;
    }
    final details = _growthChannelDetails();
    try {
      await _plugin.show(id, title, body, details, payload: payload);
    } catch (e, st) {
      debugPrint('LocalNotificationsService.showGrowthAlert($id) failed: $e\n$st');
      return;
    }
    unawaited(_persistNotificationLog(
      notifId: id,
      title: title,
      body: body,
      payload: payload,
      kind: 'shown',
      occurredAt: DateTime.now(),
    ));
  }

  static const List<int> legacyImmediateReminderIds = [1001, 1002, 1005, 1006];

  /// Devolve **true** se o SO aceitou o agendamento; **false** se falhou por completo (sem excepção
  /// em alguns Android — antes isto era silencioso).
  Future<bool> scheduleZoned({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
    String? payload,
  }) async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    await ensureCoreInitialized();
    if (!_coreInitialized) {
      debugPrint('LocalNotificationsService.scheduleZoned($id): plugin not initialized — bailing out.');
      return false;
    }
    await NotificationTimezone.init();

    var when = whenLocal;
    final now = DateTime.now();
    if (!when.isAfter(now.add(const Duration(seconds: 3)))) {
      when = now.add(const Duration(seconds: 6));
    }

    final details = _reminderChannelDetails();

    final tz.TZDateTime tzWhen;
    try {
      tzWhen = tz.TZDateTime.from(when, tz.local);
    } catch (e, st) {
      debugPrint('LocalNotificationsService.scheduleZoned($id): tz.TZDateTime.from failed: $e\n$st');
      return false;
    }
    Future<void> scheduleWithMode(AndroidScheduleMode androidMode) {
      return _plugin.zonedSchedule(
        id,
        title,
        body,
        tzWhen,
        details,
        androidScheduleMode: androidMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }

    void logScheduled() {
      unawaited(_persistNotificationLog(
        notifId: id,
        title: title,
        body: body,
        payload: payload,
        kind: 'scheduled',
        occurredAt: when,
      ));
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await scheduleWithMode(AndroidScheduleMode.exactAllowWhileIdle);
        logScheduled();
        debugPrint('LocalNotificationsService.scheduleZoned($id): scheduled exactAllowWhileIdle for $tzWhen');
        return true;
      } on PlatformException catch (e) {
        debugPrint('LocalNotificationsService.scheduleZoned($id): exactAllowWhileIdle PlatformException: $e — tentando inexactAllowWhileIdle');
      } catch (e, st) {
        debugPrint('LocalNotificationsService.scheduleZoned($id): exactAllowWhileIdle failed: $e\n$st — tentando inexactAllowWhileIdle');
      }

      try {
        await scheduleWithMode(AndroidScheduleMode.inexactAllowWhileIdle);
        logScheduled();
        debugPrint('LocalNotificationsService.scheduleZoned($id): scheduled inexactAllowWhileIdle for $tzWhen');
        return true;
      } catch (e, st) {
        debugPrint('LocalNotificationsService.scheduleZoned($id): inexactAllowWhileIdle failed: $e\n$st — tentando inexact');
      }

      try {
        await scheduleWithMode(AndroidScheduleMode.inexact);
        logScheduled();
        debugPrint('LocalNotificationsService.scheduleZoned($id): scheduled inexact for $tzWhen');
        return true;
      } catch (e, st) {
        debugPrint('LocalNotificationsService.scheduleZoned($id): ALL modes failed: $e\n$st');
        return false;
      }
    }

    try {
      await scheduleWithMode(AndroidScheduleMode.exactAllowWhileIdle);
      logScheduled();
      debugPrint('LocalNotificationsService.scheduleZoned($id): scheduled (iOS) for $tzWhen');
      return true;
    } catch (e, st) {
      debugPrint('LocalNotificationsService.scheduleZoned($id): iOS schedule failed: $e\n$st');
      return false;
    }
  }

  Future<void> _persistNotificationLog({
    int? notifId,
    required String title,
    required String body,
    String? payload,
    required String kind,
    required DateTime occurredAt,
  }) async {
    if (kIsWeb) return;
    try {
      final raw = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final uid = raw.trim().isEmpty ? 'anonymous' : raw.trim();
      // Timeout defensivo: se a BD ficar bloqueada (lock contention, init parado),
      // **não** podemos manter a referência presa — isto corre em paralelo com
      // o agendamento real do SO (via `unawaited(...)`) e é apenas observabilidade.
      await AppDatabase.instance
          .insertNotificationLog(
            notifId: notifId,
            uid: uid,
            title: title,
            body: body,
            payload: payload,
            kind: kind,
            occurredAt: occurredAt,
          )
          .timeout(const Duration(seconds: 5));
    } on TimeoutException catch (e) {
      debugPrint('LocalNotificationsService._persistNotificationLog timeout: $e');
    } catch (e, st) {
      debugPrint('LocalNotificationsService._persistNotificationLog failed: $e\n$st');
    }
  }

  Future<void> cancelNotificationIds(Iterable<int> ids) async {
    if (kIsWeb) return;
    await ensureCoreInitialized();
    for (final id in ids) {
      await _plugin.cancel(id);
    }
  }

  /// Cancela lembretes agendados + ids antigos de “show imediato”.
  Future<void> cancelAllRoutineSchedules(Iterable<int> scheduledIds) async {
    await cancelNotificationIds([...scheduledIds, ...legacyImmediateReminderIds]);
  }

}

