import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/ai/ai_message_model.dart';

/// Histórico do chat IA Babá em Firestore + overlay local (boas-vindas / otimista).
class AiChatRepository {
  AiChatRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  final List<AiMessage> _overlay = [];
  List<AiMessage> _fromFirestore = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  final StreamController<List<AiMessage>> _controller =
      StreamController<List<AiMessage>>.broadcast();

  bool _started = false;
  bool _ignoreFirestore = false;

  Stream<List<AiMessage>> watchMessages() {
    _ensureSubscription();
    _emit();
    return _controller.stream;
  }

  List<AiMessage> get snapshot => _merged();

  bool get isEmpty => _merged().isEmpty;

  void _ensureSubscription() {
    if (_started) return;
    _started = true;
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _fromFirestore = [];
      return;
    }
    _subscription = _firestore
        .collection('ai_chats')
        .doc(uid)
        .collection('messages')
        .snapshots()
        .listen(
      (snap) {
        if (_ignoreFirestore) return;
        _fromFirestore = _expandFirestoreDocs(snap.docs);
        _emit();
      },
      onError: (_) {
        _fromFirestore = [];
        _emit();
      },
    );
  }

  List<AiMessage> _expandFirestoreDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs)
      ..sort((a, b) {
        final ta = _readCreatedAt(a.data());
        final tb = _readCreatedAt(b.data());
        return ta.compareTo(tb);
      });

    final out = <AiMessage>[];
    for (final doc in sorted) {
      final data = doc.data();
      final createdAt = _readCreatedAt(data);
      final babyId = data['babyId'] as String?;
      final question = '${data['question'] ?? ''}'.trim();
      final answer = '${data['answer'] ?? ''}'.trim();
      final statusRaw = '${data['status'] ?? 'sent'}';
      final status = statusRaw == 'failed'
          ? AiMessageStatus.error
          : AiMessageStatus.sent;

      if (question.isNotEmpty) {
        out.add(
          AiMessage(
            id: '${doc.id}-user',
            text: question,
            sender: AiMessageSender.user,
            status: status,
            createdAt: createdAt,
            babyId: babyId,
          ),
        );
      }
      if (answer.isNotEmpty) {
        out.add(
          AiMessage(
            id: '${doc.id}-ai',
            text: answer,
            sender: AiMessageSender.ai,
            status: status,
            createdAt: createdAt.add(const Duration(milliseconds: 1)),
            babyId: babyId,
          ),
        );
      }
    }
    return out;
  }

  DateTime _readCreatedAt(Map<String, dynamic> data) {
    final raw = data['createdAt'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.now();
  }

  List<AiMessage> _merged() {
    final firestoreQuestions = _fromFirestore
        .where((m) => m.isUser)
        .map((m) => m.text.trim())
        .toSet();
    final firestoreAiTexts = _fromFirestore
        .where((m) => m.isAi)
        .map((m) => m.text.trim())
        .toSet();

    final overlay = _overlay.where((m) {
      final text = m.text.trim();
      if (m.isUser) return !firestoreQuestions.contains(text);
      return !firestoreAiTexts.contains(text);
    }).toList();

    final merged = [...overlay, ..._fromFirestore]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(merged);
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_merged());
    }
  }

  Future<AiMessage> add(AiMessage message) async {
    _overlay.add(message);
    _emit();
    return message;
  }

  Future<void> updateById(String id, AiMessage updated) async {
    final index = _overlay.indexWhere((m) => m.id == id);
    if (index < 0) return;
    _overlay[index] = updated;
    _emit();
  }

  void removeOverlayById(String id) {
    _overlay.removeWhere((m) => m.id == id);
    _emit();
  }

  /// Limpa UI imediatamente; ignora snapshots do Firestore até [endSessionReset].
  Future<void> beginSessionReset() async {
    _ignoreFirestore = true;
    _overlay.clear();
    _fromFirestore = [];
    _emit();
  }

  void endSessionReset() {
    _ignoreFirestore = false;
    _emit();
  }

  Future<void> clear() async {
    _overlay.clear();
    _fromFirestore = [];
    _emit();
  }

  /// Remove overlay local e reinicia assinatura (após apagar no servidor).
  Future<void> resetAfterServerClear() async {
    _overlay.clear();
    _fromFirestore = [];
    _emit();
  }

  void removeOverlayPairForDoc(String firestoreDocId) {
    _overlay.removeWhere(
      (m) => m.firestoreDocId == firestoreDocId,
    );
    _emit();
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
