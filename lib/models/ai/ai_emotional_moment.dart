/// Tipos de momentos emocionais da IA Babá (balão, feed futuro, chat).
enum AiEmotionalMomentKind {
  monthiversary,
  tbtMemory,
  achievement,
  spontaneousInsight,
}

/// Momento gerado localmente a partir do histórico do bebé.
class AiEmotionalMoment {
  const AiEmotionalMoment({
    required this.id,
    required this.kind,
    required this.prefsKey,
    required this.text,
    required this.priority,
    this.shareSnippet,
    this.metadata = const {},
  });

  final String id;
  final AiEmotionalMomentKind kind;
  /// Chave para dismiss diário (`SharedPreferences`).
  final String prefsKey;
  final String text;
  /// Menor = mais prioritário no balão.
  final int priority;
  /// Texto opcional para partilha futura.
  final String? shareSnippet;
  final Map<String, Object?> metadata;
}
