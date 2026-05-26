/// Insight automático da IA Babá (resumo, alerta, rotina, crescimento).
enum AiInsightKind {
  dailySummary,
  weeklySummary,
  monthlySummary,
  predictiveAlert,
  routineSuggestion,
  growthInsight,
}

enum AiInsightSource {
  local,
  openai,
}

class AiInsight {
  const AiInsight({
    required this.id,
    required this.kind,
    required this.text,
    required this.babyId,
    this.source = AiInsightSource.local,
    this.locale = 'pt',
    this.createdAt,
  });

  final String id;
  final AiInsightKind kind;
  final String text;
  final String babyId;
  final AiInsightSource source;
  final String locale;
  final DateTime? createdAt;

  bool get isFromOpenAi => source == AiInsightSource.openai;

  factory AiInsight.fromFirestore(
    String docId,
    Map<String, dynamic> data, {
    required AiInsightKind kind,
  }) {
    final src = '${data['source'] ?? 'local'}'.trim().toLowerCase();
    return AiInsight(
      id: docId,
      kind: kind,
      text: '${data['text'] ?? ''}'.trim(),
      babyId: '${data['babyId'] ?? data['baby_id'] ?? ''}'.trim(),
      source: src == 'openai' ? AiInsightSource.openai : AiInsightSource.local,
      locale: '${data['locale'] ?? 'pt'}',
      createdAt: _ts(data['createdAt'] ?? data['created_at']),
    );
  }

  Map<String, dynamic> toFirestoreLocal() => {
        'text': text,
        'babyId': babyId,
        'type': _typeField(kind),
        'source': 'local',
        'locale': locale,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  static String _typeField(AiInsightKind k) => switch (k) {
        AiInsightKind.dailySummary => 'daily',
        AiInsightKind.weeklySummary => 'weekly',
        AiInsightKind.monthlySummary => 'monthly',
        AiInsightKind.predictiveAlert => 'alert',
        AiInsightKind.routineSuggestion => 'routine',
        AiInsightKind.growthInsight => 'growth',
      };

  static DateTime? _ts(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse('$v');
  }
}
