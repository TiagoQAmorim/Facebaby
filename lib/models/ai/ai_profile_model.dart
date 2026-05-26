import 'package:cloud_firestore/cloud_firestore.dart';

/// Perfil de contexto da IA Babá em `ai_profiles/{userId}`.
class AiProfile {
  const AiProfile({
    this.babyId,
    this.aiHistory = '',
    this.updatedAt,
    this.createdAt,
  });

  static const int maxHistoryLength = 1500;

  final String? babyId;
  final String aiHistory;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  bool get hasHistory => aiHistory.trim().isNotEmpty;

  factory AiProfile.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return const AiProfile();
    final updated = data['updatedAt'];
    final created = data['createdAt'];
    return AiProfile(
      babyId: data['babyId'] as String?,
      aiHistory: '${data['aiHistory'] ?? ''}'.trim(),
      updatedAt: _toDate(updated),
      createdAt: _toDate(created),
    );
  }

  static DateTime? _toDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
