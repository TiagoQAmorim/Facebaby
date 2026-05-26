import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Mensagem do admin exibida no balão flutuante da IA.
class AdminBroadcastInboxItem {
  const AdminBroadcastInboxItem({
    required this.campaignId,
    required this.text,
    this.imageUrl,
    this.actionUrl,
    this.actionButtonLabel,
  });

  final String campaignId;
  final String text;
  final String? imageUrl;
  final String? actionUrl;
  final String? actionButtonLabel;

  factory AdminBroadcastInboxItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    return AdminBroadcastInboxItem(
      campaignId: doc.id,
      text: '${d['text'] ?? ''}'.trim(),
      imageUrl: _optionalString(d['imageUrl']),
      actionUrl: _optionalString(d['actionUrl']),
      actionButtonLabel: _optionalString(d['actionButtonLabel']),
    );
  }

  static String? _optionalString(Object? v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty ? null : s;
  }
}

/// Inbox `users/{uid}/inbox_broadcasts` — mensagens do painel admin.
class AdminBroadcastInboxService {
  AdminBroadcastInboxService._();
  static final AdminBroadcastInboxService instance = AdminBroadcastInboxService._();

  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<AdminBroadcastInboxItem>> watchActive() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);

    return _db
        .collection('users')
        .doc(uid)
        .collection('inbox_broadcasts')
        .limit(24)
        .snapshots()
        .map((snap) {
      final docs = snap.docs
          .where((d) => d.data()['dismissedAt'] == null)
          .toList();
      docs.sort((a, b) {
        final at = a.data()['createdAt'];
        final bt = b.data()['createdAt'];
        if (at is Timestamp && bt is Timestamp) {
          return bt.compareTo(at);
        }
        return b.id.compareTo(a.id);
      });
      final out = <AdminBroadcastInboxItem>[];
      for (final doc in docs.take(12)) {
        final item = AdminBroadcastInboxItem.fromDoc(doc);
        if (item.text.isNotEmpty) out.add(item);
      }
      return out;
    });
  }

  Future<void> dismiss(String campaignId) async {
    final uid = _uid;
    if (uid == null || campaignId.trim().isEmpty) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('inbox_broadcasts')
          .doc(campaignId)
          .set(
        {'dismissedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('AdminBroadcastInboxService.dismiss: $e');
    }
  }
}
