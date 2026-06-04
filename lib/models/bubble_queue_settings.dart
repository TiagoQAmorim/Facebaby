/// Configuração remota da fila do balão (`floating_message_settings/global`).
class BubbleQueueSettings {
  const BubbleQueueSettings({
    this.resetBefore,
    this.localQueueGeneration = 0,
  });

  /// Mensagens (Firestore + inbox) criadas antes deste instante são ignoradas.
  final DateTime? resetBefore;

  /// Incrementar para forçar purge de SharedPreferences em todos os apps.
  final int localQueueGeneration;
}
