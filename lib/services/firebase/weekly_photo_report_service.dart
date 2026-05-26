import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Denúncias de conteúdo na Foto da Semana → coleção `weekly_photo_reports`.
class WeeklyPhotoReportService {
  WeeklyPhotoReportService._();

  static final WeeklyPhotoReportService instance = WeeklyPhotoReportService._();

  static const int minMessageLength = 5;
  static const int maxMessageLength = 1000;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('weekly_photo_reports');

  Future<void> submitReport({
    required String publicMemoryId,
    required String message,
    String? photoUrl,
    String? targetUserId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('not_authenticated');
    }

    final memId = publicMemoryId.trim();
    final text = message.trim();
    if (memId.isEmpty) throw StateError('invalid_memory');
    if (text.length < minMessageLength) throw StateError('message_too_short');
    if (text.length > maxMessageLength) throw StateError('message_too_long');

    try {
      await _col.add({
        'publicMemoryId': memId,
        'reporterUid': uid,
        'reporterEmail': FirebaseAuth.instance.currentUser?.email ?? '',
        'message': text,
        'reportMessage': text,
        'photoUrl': (photoUrl ?? '').trim(),
        'targetUserId': (targetUserId ?? '').trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      debugPrint('WeeklyPhotoReportService.submitReport failed: $e\n$st');
      rethrow;
    }
  }
}
