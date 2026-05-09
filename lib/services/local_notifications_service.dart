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

    _coreInitialized = true;



    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const ios = DarwinInitializationSettings();

    const initSettings = InitializationSettings(android: android, iOS: ios);

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

    final details = _reminderChannelDetails();

    await _plugin.show(id, title, body, details, payload: payload);
    await _persistNotificationLog(
      notifId: id,
      title: title,
      body: body,
      payload: payload,
      kind: 'shown',
      occurredAt: DateTime.now(),
    );

  }

  Future<void> showGrowthAlert({

    required int id,

    required String title,

    required String body,

    String? payload,

  }) async {

    if (kIsWeb) return;

    await ensureCoreInitialized();

    final details = _growthChannelDetails();

    await _plugin.show(id, title, body, details, payload: payload);
    await _persistNotificationLog(
      notifId: id,
      title: title,
      body: body,
      payload: payload,
      kind: 'shown',
      occurredAt: DateTime.now(),
    );

  }

  static const List<int> legacyImmediateReminderIds = [1001, 1002, 1005, 1006];

  /// Agendamento real do SO (dispara com app fechado). Requer [NotificationTimezone.init] antes.
  Future<void> scheduleZoned({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
    String? payload,
  }) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    await ensureCoreInitialized();
    await NotificationTimezone.init();

    var when = whenLocal;
    final now = DateTime.now();
    if (!when.isAfter(now.add(const Duration(seconds: 3)))) {
      when = now.add(const Duration(seconds: 6));
    }

    final details = _reminderChannelDetails();

    final tzWhen = tz.TZDateTime.from(when, tz.local);
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

    Future<void> logScheduled() => _persistNotificationLog(
          notifId: id,
          title: title,
          body: body,
          payload: payload,
          kind: 'scheduled',
          occurredAt: when,
        );

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Ordem: exato → inexact+idle → inexact simples (máxima hipótese de o AlarmManager aceitar).
      try {
        await scheduleWithMode(AndroidScheduleMode.exactAllowWhileIdle);
        await logScheduled();
        return;
      } on PlatformException catch (_) {
        // Permissão negada ou OEM — tenta modos mais permissivos abaixo.
      } catch (_) {}

      try {
        await scheduleWithMode(AndroidScheduleMode.inexactAllowWhileIdle);
        await logScheduled();
        return;
      } catch (_) {}

      await scheduleWithMode(AndroidScheduleMode.inexact);
      await logScheduled();
      return;
    }

    await scheduleWithMode(AndroidScheduleMode.exactAllowWhileIdle);
    await logScheduled();
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
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      await AppDatabase.instance.insertNotificationLog(
        notifId: notifId,
        uid: uid,
        title: title,
        body: body,
        payload: payload,
        kind: kind,
        occurredAt: occurredAt,
      );
    } catch (_) {}
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

