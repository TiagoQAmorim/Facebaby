/// Ação pendente da conversa (orquestrador — não é chat genérico).
class AiPendingAction {
  const AiPendingAction({
    required this.type,
    this.awaitingField,
    this.recordType,
    this.recordIndex,
    this.collectedData = const {},
  });

  /// Ex.: finish_sleep, complete_diaper, complete_feeding, confirm_records
  final String type;
  final String? awaitingField;
  final String? recordType;
  final int? recordIndex;
  final Map<String, dynamic> collectedData;

  Map<String, dynamic> toMap() => {
        'type': type,
        if (awaitingField != null) 'awaitingField': awaitingField,
        if (recordType != null) 'recordType': recordType,
        if (recordIndex != null) 'recordIndex': recordIndex,
        if (collectedData.isNotEmpty) 'collectedData': collectedData,
      };

  factory AiPendingAction.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const AiPendingAction(type: 'none');
    final raw = m['collectedData'];
    Map<String, dynamic> data = const {};
    if (raw is Map) {
      data = Map<String, dynamic>.from(raw);
    }
    return AiPendingAction(
      type: '${m['type'] ?? 'none'}',
      awaitingField: m['awaitingField'] as String?,
      recordType: m['recordType'] as String?,
      recordIndex: (m['recordIndex'] as num?)?.toInt(),
      collectedData: data,
    );
  }
}

/// Estado persistido `ai_conversation_state/{userId}`.
class AiConversationState {
  const AiConversationState({
    this.pendingAction,
    this.awaitingFields = const [],
    this.collectedData = const {},
    this.updatedAt,
    this.expiresAt,
    this.babyId,
  });

  final AiPendingAction? pendingAction;
  final List<String> awaitingFields;
  final Map<String, dynamic> collectedData;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final int? babyId;

  bool get hasPending =>
      pendingAction != null &&
      pendingAction!.type != 'none' &&
      pendingAction!.type.isNotEmpty;

  bool get isExpired {
    final exp = expiresAt;
    if (exp == null) return false;
    return DateTime.now().isAfter(exp);
  }

  Map<String, dynamic> toMap() => {
        if (pendingAction != null) 'pendingAction': pendingAction!.toMap(),
        'awaitingFields': awaitingFields,
        if (collectedData.isNotEmpty) 'collectedData': collectedData,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        if (babyId != null) 'babyId': babyId,
      };

  factory AiConversationState.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const AiConversationState();
    final awaiting = m['awaitingFields'];
    final collected = m['collectedData'];
    return AiConversationState(
      pendingAction: AiPendingAction.fromMap(
        m['pendingAction'] is Map
            ? Map<String, dynamic>.from(m['pendingAction'] as Map)
            : null,
      ),
      awaitingFields: awaiting is List
          ? awaiting.map((e) => '$e').toList()
          : const [],
      collectedData: collected is Map
          ? Map<String, dynamic>.from(collected)
          : const {},
      updatedAt: DateTime.tryParse('${m['updatedAt'] ?? ''}'),
      expiresAt: DateTime.tryParse('${m['expiresAt'] ?? ''}'),
      babyId: (m['babyId'] as num?)?.toInt(),
    );
  }
}
