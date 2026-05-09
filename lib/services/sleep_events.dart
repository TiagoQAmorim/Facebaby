import 'package:flutter/foundation.dart';

/// Lista de registos de sono mudou (gravado novo período).
class SleepEvents {
  SleepEvents._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void ping() {
    revision.value = revision.value + 1;
  }
}
