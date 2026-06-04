import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/bubble_queue_settings.dart';
import '../repositories/floating_message_repository.dart';

/// Mensagem do admin exibida no balão flutuante da IA.
class AdminBroadcastInboxItem {
  const AdminBroadcastInboxItem({
    required this.campaignId,
    required this.text,
    this.title,
    this.imageUrl,
    this.actionUrl,
    this.actionButtonLabel,
    this.createdAt,
  });

  final String campaignId;
  final String text;
  final String? title;
  final String? imageUrl;
  final String? actionUrl;
  final String? actionButtonLabel;
  final DateTime? createdAt;

  factory AdminBroadcastInboxItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    final text = _broadcastText(d);
    return AdminBroadcastInboxItem(
      campaignId: doc.id,
      text: text,
      title: _optionalString(d['title']),
      imageUrl: _optionalString(d['imageUrl']),
      actionUrl: _optionalString(d['actionUrl']),
      actionButtonLabel: _optionalString(d['actionButtonLabel']),
      createdAt: _createdAtFrom(d['createdAt']),
    );
  }

  static DateTime? _createdAtFrom(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  bool get hasRenderableContent =>
      text.trim().isNotEmpty || (imageUrl?.trim().isNotEmpty ?? false);

  static String? _optionalString(Object? v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty ? null : s;
  }

  static String _broadcastText(Map<String, dynamic> d) {
    final parts = <String>[
      '${d['text'] ?? ''}'.trim(),
      '${d['message'] ?? ''}'.trim(),
      '${d['title'] ?? ''}'.trim(),
    ].where((s) => s.isNotEmpty);
    return parts.join('\n\n');
  }
}

/// Inbox `users/{uid}/inbox_broadcasts` — mensagens do painel admin.
class AdminBroadcastInboxService {
  AdminBroadcastInboxService._();
  static final AdminBroadcastInboxService instance = AdminBroadcastInboxService._();

  final _db = FirebaseFirestore.instance;
  final _settingsRepo = FloatingMessageRepository();

  BubbleQueueSettings _cachedSettings = const BubbleQueueSettings();
  DateTime? _settingsCachedAt;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<BubbleQueueSettings> _bubbleSettings() async {
    final prev = _settingsCachedAt;
    if (prev != null &&
        DateTime.now().difference(prev) < const Duration(minutes: 3)) {
      return _cachedSettings;
    }
    _cachedSettings = await _settingsRepo.fetchBubbleQueueSettings();
    _settingsCachedAt = DateTime.now();
    return _cachedSettings;
  }

  void invalidateSettingsCache() {
    _settingsCachedAt = null;
  }

  Stream<List<AdminBroadcastInboxItem>> watchActive() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);

    return _db
        .collection('users')
        .doc(uid)
        .collection('inbox_broadcasts')
        .limit(24)
        .snapshots()
        .asyncMap((snap) async {
      final settings = await _bubbleSettings();
      return _itemsFromSnapshot(snap, resetBefore: settings.resetBefore);
    });
  }

  /// Leitura pontual (evita `.first` em stream com timeout vazio).
  Future<List<AdminBroadcastInboxItem>> fetchActiveOnce() async {
    final uid = _uid;
    if (uid == null) return const [];
    try {
      final settings = await _bubbleSettings();
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('inbox_broadcasts')
          .limit(24)
          .get();
      return _itemsFromSnapshot(snap, resetBefore: settings.resetBefore);
    } catch (e) {
      debugPrint('AdminBroadcastInboxService.fetchActiveOnce: $e');
      return const [];
    }
  }

  static bool _passesResetBefore(DateTime? createdAt, DateTime? resetBefore) {
    if (resetBefore == null) return true;
    if (createdAt == null) return false;
    return !createdAt.isBefore(resetBefore);
  }

  static List<AdminBroadcastInboxItem> _itemsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap, {
    DateTime? resetBefore,
  }) {
    final docs =
        snap.docs.where((d) => d.data()['dismissedAt'] == null).toList();
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
      if (!_passesResetBefore(item.createdAt, resetBefore)) continue;
      if (item.hasRenderableContent) out.add(item);
    }
    return out;
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
