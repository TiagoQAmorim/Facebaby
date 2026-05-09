import 'package:flutter/foundation.dart';

/// Sinaliza mudanças em registos de crescimento (peso / altura / cabeça) para alertas locais e UI.
class GrowthEvents {
  GrowthEvents._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void ping() {
    revision.value = revision.value + 1;
  }
}
