import 'detected_baby_record.dart';

/// Resultado estruturado de [parseAiNannyMessage] (local ou Cloud Function).
class AiNannyParseResult {
  const AiNannyParseResult({
    required this.classification,
    this.records = const [],
    this.needsConfirmation = false,
  });

  /// `create_records` | `chat_only`
  final String classification;
  final List<AiNannyStructuredRecord> records;
  final bool needsConfirmation;

  bool get hasRecords =>
      classification == 'create_records' && records.isNotEmpty;

  factory AiNannyParseResult.fromMap(Map<String, dynamic> m) {
    final rawRecords = m['records'];
    final list = <AiNannyStructuredRecord>[];
    if (rawRecords is List) {
      for (final item in rawRecords) {
        if (item is Map) {
          list.add(AiNannyStructuredRecord.fromMap(
            Map<String, dynamic>.from(item),
          ));
        }
      }
    }
    return AiNannyParseResult(
      classification: '${m['classification'] ?? 'chat_only'}'.trim(),
      records: list,
      needsConfirmation: m['needsConfirmation'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'classification': classification,
        'records': records.map((r) => r.toMap()).toList(),
        'needsConfirmation': needsConfirmation,
      };
}

/// Um registro extraído da frase (formato FaceBaby).
class AiNannyStructuredRecord {
  const AiNannyStructuredRecord({
    required this.type,
    this.missingFields = const [],
    this.fields = const {},
  });

  final String type;
  final List<String> missingFields;
  final Map<String, dynamic> fields;

  bool get isComplete => missingFields.isEmpty;

  T? field<T>(String key) {
    final v = fields[key];
    if (v is T) return v;
    return null;
  }

  factory AiNannyStructuredRecord.fromMap(Map<String, dynamic> m) {
    final missing = m['missingFields'];
    return AiNannyStructuredRecord(
      type: '${m['type'] ?? ''}'.trim().toLowerCase(),
      missingFields: missing is List
          ? missing.map((e) => '$e').toList()
          : const [],
      fields: Map<String, dynamic>.from(m)
        ..remove('type')
        ..remove('missingFields'),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'missingFields': missingFields,
        ...fields,
      };

  /// Mapa canónico para testes (campos estáveis, idioma-agnóstico).
  Map<String, dynamic> toCanonicalMap() {
    final m = <String, dynamic>{'type': type, ...fields};
    m.remove('time');
    m.remove('notes');
    if (missingFields.isNotEmpty) {
      m['missingFields'] = List<String>.from(missingFields)..sort();
    }
    return m;
  }
}

/// Compara registros ignorando ordem de chaves e campos de UI.
bool canonicalRecordsEqual(
  List<AiNannyStructuredRecord> a,
  List<AiNannyStructuredRecord> b,
) {
  if (a.length != b.length) return false;
  final mapsA = a.map((r) => r.toCanonicalMap()).toList()
    ..sort((x, y) => '$x'.compareTo('$y'));
  final mapsB = b.map((r) => r.toCanonicalMap()).toList()
    ..sort((x, y) => '$x'.compareTo('$y'));
  for (var i = 0; i < mapsA.length; i++) {
    if (!_deepEquals(mapsA[i], mapsB[i])) return false;
  }
  return true;
}

bool _deepEquals(Object? x, Object? y) {
  if (x is Map && y is Map) {
    if (x.length != y.length) return false;
    for (final k in x.keys) {
      if (!y.containsKey(k)) return false;
      if (!_deepEquals(x[k], y[k])) return false;
    }
    return true;
  }
  if (x is List && y is List) {
    if (x.length != y.length) return false;
    for (var i = 0; i < x.length; i++) {
      if (!_deepEquals(x[i], y[i])) return false;
    }
    return true;
  }
  return x == y;
}

/// Rascunho pronto para UI de confirmação.
enum AiNannyRecordDraftStatus {
  complete,
  incomplete,
  needsConfirm,
}

class AiNannyRecordDraft {
  const AiNannyRecordDraft({
    required this.structured,
    required this.status,
    required this.displayLine,
    required this.title,
    this.detailLines = const [],
    this.understoodLines = const [],
    this.missingLines = const [],
    this.followUpQuestion,
    this.detected,
    this.growthPreview,
  });

  final AiNannyStructuredRecord structured;
  final AiNannyRecordDraftStatus status;
  final String displayLine;
  final String title;
  final List<String> detailLines;
  final List<String> understoodLines;
  final List<String> missingLines;
  final String? followUpQuestion;
  final DetectedBabyRecord? detected;
  final AiNannyGrowthPreview? growthPreview;

  bool get hasCardContent =>
      title.trim().isNotEmpty ||
      understoodLines.isNotEmpty ||
      missingLines.isNotEmpty ||
      detailLines.isNotEmpty ||
      displayLine.trim().isNotEmpty;
}

class AiNannyGrowthPreview {
  const AiNannyGrowthPreview({
    required this.measurementType,
    required this.previousValue,
    required this.newValue,
    required this.unitLabel,
  });

  final String measurementType;
  final double previousValue;
  final double newValue;
  final String unitLabel;
}

class AiNannyRecordsBundle {
  const AiNannyRecordsBundle({
    required this.drafts,
    required this.userMessage,
    this.followUpQuestions = const [],
    this.usedExtractionFallback = false,
  });

  final List<AiNannyRecordDraft> drafts;
  final String userMessage;
  final List<AiFollowUpQuestion> followUpQuestions;
  final bool usedExtractionFallback;

  int get completeCount =>
      drafts.where((d) => d.status == AiNannyRecordDraftStatus.complete).length;

  int get incompleteCount =>
      drafts.where((d) => d.status == AiNannyRecordDraftStatus.incomplete).length;

  int get confirmCount => drafts
      .where((d) => d.status == AiNannyRecordDraftStatus.needsConfirm)
      .length;

  bool get allRequiredFilled =>
      drafts.isNotEmpty &&
      drafts.every(
        (d) =>
            d.structured.missingFields.isEmpty &&
            (d.status == AiNannyRecordDraftStatus.complete ||
                d.status == AiNannyRecordDraftStatus.needsConfirm),
      ) &&
      followUpQuestions.isEmpty;
}
