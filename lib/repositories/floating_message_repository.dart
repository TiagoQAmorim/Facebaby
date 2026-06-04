import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/bubble_queue_settings.dart';
import '../models/floating_message_model.dart';
import '../services/admin_broadcast_inbox_service.dart';

/// Firestore: `floating_messages` + `floating_message_reads/{uid}/messages`.
class FloatingMessageRepository {
  FloatingMessageRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  static const String settingsCollection = 'floating_message_settings';
  static const String settingsGlobalDoc = 'global';

  /// Mensagens com `createdAt` anterior a este instante são ignoradas no app.
  Future<DateTime?> fetchResetBefore() async {
    return (await fetchBubbleQueueSettings()).resetBefore;
  }

  Future<BubbleQueueSettings> fetchBubbleQueueSettings() async {
    try {
      final snap = await _db
          .collection(settingsCollection)
          .doc(settingsGlobalDoc)
          .get();
      if (!snap.exists) {
        return const BubbleQueueSettings();
      }
      final data = snap.data() ?? {};
      final raw = data['resetBefore'];
      DateTime? resetBefore;
      if (raw is Timestamp) {
        resetBefore = raw.toDate();
      } else if (raw is DateTime) {
        resetBefore = raw;
      } else if (raw is String) {
        resetBefore = DateTime.tryParse(raw);
      }
      final genRaw = data['localQueueGeneration'];
      final generation = switch (genRaw) {
        int g => g,
        num g => g.toInt(),
        String g => int.tryParse(g) ?? 0,
        _ => 0,
      };
      return BubbleQueueSettings(
        resetBefore: resetBefore,
        localQueueGeneration: generation,
      );
    } catch (e) {
      debugPrint('FloatingMessageRepository.fetchBubbleQueueSettings: $e');
      return const BubbleQueueSettings();
    }
  }

  /// Até [limit] mensagens ativas (filtro de datas no serviço).
  Future<List<FloatingMessage>> fetchActiveMessages({int limit = 40}) async {
    final snap = await _db
        .collection('floating_messages')
        .where('active', isEqualTo: true)
        .limit(limit.clamp(1, 50))
        .get();
    final items = snap.docs.map(FloatingMessage.fromFirestore).toList();
    items.sort((a, b) {
      final p = b.priority.compareTo(a.priority);
      if (p != 0) return p;
      final ac = a.createdAt;
      final bc = b.createdAt;
      if (ac != null && bc != null) return bc.compareTo(ac);
      return b.id.compareTo(a.id);
    });
    return items;
  }

  Stream<List<FloatingMessage>> watchActiveMessages({int limit = 40}) {
    return _db
        .collection('floating_messages')
        .where('active', isEqualTo: true)
        .limit(limit.clamp(1, 50))
        .snapshots()
        .map((snap) {
      final items = snap.docs.map(FloatingMessage.fromFirestore).toList();
      items.sort((a, b) {
        final p = b.priority.compareTo(a.priority);
        if (p != 0) return p;
        final ac = a.createdAt;
        final bc = b.createdAt;
        if (ac != null && bc != null) return bc.compareTo(ac);
        return b.id.compareTo(a.id);
      });
      return items;
    });
  }

  /// Legado: inbox por usuário até migração completa.
  Future<List<FloatingMessage>> fetchLegacyInbox() async {
    final inbox = await AdminBroadcastInboxService.instance.fetchActiveOnce();
    return inbox
        .map(
          (e) => FloatingMessage.fromInboxBroadcast(
            campaignId: e.campaignId,
            text: e.text,
            title: e.title,
            imageUrl: e.imageUrl,
            actionUrl: e.actionUrl,
            actionButtonLabel: e.actionButtonLabel,
            createdAt: e.createdAt,
          ),
        )
        .toList();
  }

  Future<FloatingMessageReadState?> readStateFor(String messageId) async {
    final uid = _uid;
    if (uid == null) return null;
    final snap = await _db
        .collection('floating_message_reads')
        .doc(uid)
        .collection('messages')
        .doc(messageId)
        .get();
    if (!snap.exists) return null;
    return FloatingMessageReadState.fromMap(snap.data());
  }

  Future<Map<String, FloatingMessageReadState>> readStatesFor(
    Iterable<String> messageIds,
  ) async {
    final uid = _uid;
    if (uid == null || messageIds.isEmpty) return {};
    final out = <String, FloatingMessageReadState>{};
    final ids = messageIds.toSet().toList();
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      final snap = await _db
          .collection('floating_message_reads')
          .doc(uid)
          .collection('messages')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        out[doc.id] = FloatingMessageReadState.fromMap(doc.data());
      }
    }
    return out;
  }

  Future<void> markSeen(String messageId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .collection('floating_message_reads')
          .doc(uid)
          .collection('messages')
          .doc(messageId)
          .set(
        {'seenAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('FloatingMessageRepository.markSeen: $e');
    }
  }

  Future<void> markDismissed(String messageId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .collection('floating_message_reads')
          .doc(uid)
          .collection('messages')
          .doc(messageId)
          .set(
        {
          'dismissedAt': FieldValue.serverTimestamp(),
          'seenAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('FloatingMessageRepository.markDismissed: $e');
    }
  }

  Future<void> markClicked(String messageId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .collection('floating_message_reads')
          .doc(uid)
          .collection('messages')
          .doc(messageId)
          .set(
        {
          'clickedAt': FieldValue.serverTimestamp(),
          'seenAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('FloatingMessageRepository.markClicked: $e');
    }
  }

  Future<void> dismissLegacyInbox(String campaignId) async {
    await AdminBroadcastInboxService.instance.dismiss(campaignId);
  }
}
