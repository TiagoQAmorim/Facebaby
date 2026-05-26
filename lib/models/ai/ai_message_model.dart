/// Remetente de uma mensagem no chat da IA Babá.
enum AiMessageSender {
  user,
  ai,
}

/// Estado de entrega da mensagem.
enum AiMessageStatus {
  sending,
  sent,
  error,
}

/// Uma mensagem do chat IA Babá (Fase 3 — modelo local).
class AiMessage {
  const AiMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.status,
    required this.createdAt,
    this.babyId,
    this.userId,
  });

  final String id;
  final String text;
  final AiMessageSender sender;
  final AiMessageStatus status;
  final DateTime createdAt;
  final String? babyId;
  final String? userId;

  bool get isUser => sender == AiMessageSender.user;
  bool get isAi => sender == AiMessageSender.ai;

  AiMessage copyWith({
    String? id,
    String? text,
    AiMessageSender? sender,
    AiMessageStatus? status,
    DateTime? createdAt,
    String? babyId,
    String? userId,
  }) {
    return AiMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      babyId: babyId ?? this.babyId,
      userId: userId ?? this.userId,
    );
  }

  static String newId() =>
      'msg-${DateTime.now().microsecondsSinceEpoch}';

  /// ID do documento Firestore (`ai_chats/{uid}/messages/{id}`), se existir.
  String? get firestoreDocId {
    if (id.endsWith('-user')) return id.substring(0, id.length - 5);
    if (id.endsWith('-ai')) return id.substring(0, id.length - 3);
    return null;
  }

  bool get isLocalOnly => firestoreDocId == null;
}
