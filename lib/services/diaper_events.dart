import 'package:flutter/foundation.dart';

class DiaperEvents {
  DiaperEvents._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void ping() {
    revision.value = revision.value + 1;
  }
}

