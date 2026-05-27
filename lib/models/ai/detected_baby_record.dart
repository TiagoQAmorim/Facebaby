/// Registro detectado pela extração estruturada (UI + confirmação).
class DetectedBabyRecord {
  const DetectedBabyRecord({
    required this.type,
    this.confidence = 1.0,
    this.extractedFields = const {},
    this.missingFields = const [],
    this.suggestedTime,
    this.canSave = false,
    this.understoodLines = const [],
    this.missingLines = const [],
  });

  final String type;
  final double confidence;
  final Map<String, dynamic> extractedFields;
  final List<String> missingFields;
  final DateTime? suggestedTime;
  final bool canSave;
  final List<String> understoodLines;
  final List<String> missingLines;

  DetectedBabyRecord copyWith({
    String? type,
    double? confidence,
    Map<String, dynamic>? extractedFields,
    List<String>? missingFields,
    DateTime? suggestedTime,
    bool? canSave,
    List<String>? understoodLines,
    List<String>? missingLines,
  }) {
    return DetectedBabyRecord(
      type: type ?? this.type,
      confidence: confidence ?? this.confidence,
      extractedFields: extractedFields ?? this.extractedFields,
      missingFields: missingFields ?? this.missingFields,
      suggestedTime: suggestedTime ?? this.suggestedTime,
      canSave: canSave ?? this.canSave,
      understoodLines: understoodLines ?? this.understoodLines,
      missingLines: missingLines ?? this.missingLines,
    );
  }
}

/// Pergunta de follow-up com opções ou input numérico.
class AiFollowUpQuestion {
  const AiFollowUpQuestion({
    required this.recordIndex,
    required this.recordType,
    required this.field,
    required this.question,
    this.options = const [],
    this.inputType = AiFollowUpInputType.choice,
  });

  final int recordIndex;
  final String recordType;
  final String field;
  final String question;
  final List<String> options;
  final AiFollowUpInputType inputType;
}

enum AiFollowUpInputType { choice, number, text }

/// Resultado JSON da extração (cloud ou local).
class AiExtractionResult {
  const AiExtractionResult({
    this.records = const [],
    this.followUpQuestions = const [],
    this.usedFallback = false,
  });

  final List<DetectedBabyRecord> records;
  final List<AiFollowUpQuestion> followUpQuestions;
  final bool usedFallback;

  bool get hasRecords => records.isNotEmpty;
  bool get allCanSave => records.isNotEmpty && records.every((r) => r.canSave);
}
