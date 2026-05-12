import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Inicialização necessária para [zonedSchedule] (notificações com app fechado).
class NotificationTimezone {
  NotificationTimezone._();

  static bool _ready = false;

  static Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
      _ready = true;
    } catch (e, st) {
      _ready = false;
      debugPrint('NotificationTimezone.init failed: $e\n$st');
    }
  }
}
