import 'package:flutter/foundation.dart';

/// Mudanças em vacinas ou consultas que afetam o resumo por dia na Home.
class HealthCalendarEvents {
  HealthCalendarEvents._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void ping() {
    revision.value = revision.value + 1;
  }
}
