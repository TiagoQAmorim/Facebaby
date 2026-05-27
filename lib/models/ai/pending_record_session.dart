import 'ai_nanny_parsed_message.dart';
import 'current_pending_question.dart';
import 'detected_baby_record.dart';

export 'current_pending_question.dart';

/// Estado da máquina de confirmação de registros da IA Babá.
enum PendingRecordSessionStatus {
  collectingInfo,
  readyToConfirm,
  saved,
  cancelled,
}

/// Sessão persistente enquanto faltam campos obrigatórios.
class PendingRecordSession {
  const PendingRecordSession({
    required this.sessionId,
    required this.bundle,
    required this.createdAt,
    this.currentQuestionIndex = 0,
    this.clarificationReplies = '',
    this.status = PendingRecordSessionStatus.collectingInfo,
  });

  final String sessionId;
  final AiNannyRecordsBundle bundle;
  final DateTime createdAt;
  final int currentQuestionIndex;
  final String clarificationReplies;
  final PendingRecordSessionStatus status;

  List<AiFollowUpQuestion> get pendingQuestions => bundle.followUpQuestions;

  /// Primeira pergunta pendente (sempre índice 0 após recalcular follow-ups).
  AiFollowUpQuestion? get currentQuestion {
    final qs = pendingQuestions;
    if (qs.isEmpty) return null;
    final idx = currentQuestionIndex.clamp(0, qs.length - 1);
    return qs[idx];
  }

  /// Pergunta explícita atual — usada no chat, voz e UI de opções.
  CurrentPendingQuestion? get currentPendingQuestion {
    final q = currentQuestion;
    if (q == null) return null;
    return CurrentPendingQuestion.fromFollowUp(q);
  }

  bool get canSave => bundle.allRequiredFilled;

  bool get isCollecting =>
      status == PendingRecordSessionStatus.collectingInfo && !canSave;

  /// Só bloqueia chat genérico enquanto há pergunta de registro ativa.
  /// Em [readyToConfirm] a família pode conversar e confirmar no card.
  bool get blocksGenericChat =>
      status == PendingRecordSessionStatus.collectingInfo &&
      pendingQuestions.isNotEmpty;

  PendingRecordSession copyWith({
    AiNannyRecordsBundle? bundle,
    int? currentQuestionIndex,
    String? clarificationReplies,
    PendingRecordSessionStatus? status,
  }) {
    return PendingRecordSession(
      sessionId: sessionId,
      bundle: bundle ?? this.bundle,
      createdAt: createdAt,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      clarificationReplies: clarificationReplies ?? this.clarificationReplies,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => {
        'sessionId': sessionId,
        'createdAt': createdAt.toIso8601String(),
        'currentQuestionIndex': currentQuestionIndex,
        'clarificationReplies': clarificationReplies,
        'status': status.name,
        'bundle': _bundleToMap(bundle),
      };

  static PendingRecordSession? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final bundle = _bundleFromMap(m['bundle']);
    if (bundle == null) return null;
    final statusRaw = '${m['status'] ?? ''}';
    final status = PendingRecordSessionStatus.values.firstWhere(
      (e) => e.name == statusRaw,
      orElse: () => PendingRecordSessionStatus.collectingInfo,
    );
    return PendingRecordSession(
      sessionId: '${m['sessionId'] ?? ''}',
      bundle: bundle,
      createdAt: DateTime.tryParse('${m['createdAt'] ?? ''}') ?? DateTime.now(),
      currentQuestionIndex: (m['currentQuestionIndex'] as num?)?.toInt() ?? 0,
      clarificationReplies: '${m['clarificationReplies'] ?? ''}',
      status: status,
    );
  }

  static Map<String, dynamic> _bundleToMap(AiNannyRecordsBundle b) => {
        'userMessage': b.userMessage,
        'usedExtractionFallback': b.usedExtractionFallback,
        'followUpQuestions': b.followUpQuestions.map(_questionToMap).toList(),
        'drafts': b.drafts
            .map(
              (d) => {
                'structured': d.structured.toMap(),
                'status': d.status.name,
                'displayLine': d.displayLine,
                'title': d.title,
                'detailLines': d.detailLines,
                'understoodLines': d.understoodLines,
                'missingLines': d.missingLines,
                'followUpQuestion': d.followUpQuestion,
              },
            )
            .toList(),
      };

  static AiNannyRecordsBundle? _bundleFromMap(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final draftsRaw = m['drafts'];
    if (draftsRaw is! List) return null;
    final drafts = <AiNannyRecordDraft>[];
    for (final item in draftsRaw) {
      if (item is! Map) continue;
      final d = Map<String, dynamic>.from(item);
      final sRaw = d['structured'];
      if (sRaw is! Map) continue;
      final structured = AiNannyStructuredRecord.fromMap(
        Map<String, dynamic>.from(sRaw),
      );
      final statusName = '${d['status'] ?? 'incomplete'}';
      final status = AiNannyRecordDraftStatus.values.firstWhere(
        (e) => e.name == statusName,
        orElse: () => AiNannyRecordDraftStatus.incomplete,
      );
      drafts.add(
        AiNannyRecordDraft(
          structured: structured,
          status: status,
          displayLine: '${d['displayLine'] ?? ''}',
          title: '${d['title'] ?? ''}',
          detailLines: (d['detailLines'] as List?)?.map((e) => '$e').toList() ??
              const [],
          understoodLines:
              (d['understoodLines'] as List?)?.map((e) => '$e').toList() ??
                  const [],
          missingLines:
              (d['missingLines'] as List?)?.map((e) => '$e').toList() ??
                  const [],
          followUpQuestion: d['followUpQuestion'] as String?,
        ),
      );
    }
    final followRaw = m['followUpQuestions'];
    final followUps = <AiFollowUpQuestion>[];
    if (followRaw is List) {
      for (final item in followRaw) {
        if (item is Map) {
          followUps.add(_questionFromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return AiNannyRecordsBundle(
      drafts: drafts,
      userMessage: '${m['userMessage'] ?? ''}',
      followUpQuestions: followUps,
      usedExtractionFallback: m['usedExtractionFallback'] == true,
    );
  }

  static Map<String, dynamic> _questionToMap(AiFollowUpQuestion q) => {
        'recordIndex': q.recordIndex,
        'recordType': q.recordType,
        'field': q.field,
        'question': q.question,
        'options': q.options,
        'inputType': q.inputType.name,
      };

  static AiFollowUpQuestion _questionFromMap(Map<String, dynamic> m) {
    final inputName = '${m['inputType'] ?? 'choice'}';
    final inputType = AiFollowUpInputType.values.firstWhere(
      (e) => e.name == inputName,
      orElse: () => AiFollowUpInputType.choice,
    );
    return AiFollowUpQuestion(
      recordIndex: (m['recordIndex'] as num?)?.toInt() ?? 0,
      recordType: '${m['recordType'] ?? ''}',
      field: '${m['field'] ?? ''}',
      question: '${m['question'] ?? ''}',
      options: (m['options'] as List?)?.map((e) => '$e').toList() ?? const [],
      inputType: inputType,
    );
  }
}
