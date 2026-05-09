import 'package:flutter/foundation.dart';

/// Sinaliza que a lista de registros de alimentação mudou (DB), para atualizar widgets como a Home.
class FeedingEvents {
  FeedingEvents._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void ping() {
    revision.value = revision.value + 1;
  }
}
