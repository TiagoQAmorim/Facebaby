import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import 'weekly_photo_schedule.dart';

/// Chave diária `yyyyMMdd` alinhada ao servidor (America/Sao_Paulo).
abstract final class FamilyDateKeys {
  FamilyDateKeys._();

  static String todayCompact([DateTime? instant]) {
    final when = instant ?? DateTime.now();
    try {
      final loc = tz.getLocation(WeeklyPhotoSchedule.contestTimeZoneId);
      final z = tz.TZDateTime.fromMillisecondsSinceEpoch(
        loc,
        when.millisecondsSinceEpoch,
      );
      return DateFormat('yyyyMMdd')
          .format(DateTime(z.year, z.month, z.day));
    } catch (_) {
      return DateFormat('yyyyMMdd').format(when);
    }
  }
}
