import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/ai/ai_conversation_state.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../models/ai/pending_record_session.dart';

/// `ai_conversation_state/{userId}` — pendências entre turnos.
class AiConversationStateRepository {
  AiConversationStateRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const _collection = 'ai_conversation_state';
  static const _ttlHours = 24;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? _doc() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return null;
    return _db.collection(_collection).doc(uid);
  }

  Future<AiConversationState> load() async {
    final ref = _doc();
    if (ref == null) return const AiConversationState();
    try {
      final snap = await ref.get();
      if (!snap.exists) return const AiConversationState();
      final state = AiConversationState.fromMap(snap.data());
      if (state.isExpired) {
        await clear();
        return const AiConversationState();
      }
      return state;
    } catch (e) {
      debugPrint('AiConversationStateRepository.load: $e');
      return const AiConversationState();
    }
  }

  Future<void> syncFromPendingSession({
    required PendingRecordSession? session,
    required int? babyId,
  }) async {
    final ref = _doc();
    if (ref == null) return;

    if (session == null || !session.blocksGenericChat) {
      await clear();
      return;
    }

    final q = session.currentQuestion;
    final awaiting = <String>[];
    if (q != null) awaiting.add(q.field);

    final actionType = session.canSave
        ? 'confirm_records'
        : q != null
            ? 'collect_field'
            : 'confirm_records';

    final now = DateTime.now();
    final state = AiConversationState(
      pendingAction: AiPendingAction(
        type: actionType,
        awaitingField: q?.field,
        recordType: q?.recordType,
        recordIndex: q?.recordIndex,
        collectedData: {
          'sessionId': session.sessionId,
          'userMessage': session.bundle.userMessage,
        },
      ),
      awaitingFields: awaiting,
      babyId: babyId,
      updatedAt: now,
      expiresAt: now.add(const Duration(hours: _ttlHours)),
    );

    try {
      await ref.set(state.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('AiConversationStateRepository.sync: $e');
    }
  }

  Future<void> clear() async {
    final ref = _doc();
    if (ref == null) return;
    try {
      await ref.delete();
    } catch (e) {
      debugPrint('AiConversationStateRepository.clear: $e');
    }
  }
}
