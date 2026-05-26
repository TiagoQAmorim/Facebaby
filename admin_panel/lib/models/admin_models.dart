import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/admin_photo_loader.dart' show photoFromMap;

enum UserPlan { free, premium, aiNanny }

enum UserStatus { active, suspended }

UserPlan planFromData(Map<String, dynamic>? data) {
  final override = (data?['adminPlan'] as String?)?.trim().toLowerCase();
  if (override == 'ai_nanny' || override == 'ai-nanny') return UserPlan.aiNanny;
  if (override == 'premium') return UserPlan.premium;
  if (data?['premiumLifetime'] == true) return UserPlan.premium;
  return UserPlan.free;
}

UserStatus statusFromData(Map<String, dynamic>? data) {
  final s = (data?['status'] as String?)?.trim().toLowerCase();
  return s == 'suspended' ? UserStatus.suspended : UserStatus.active;
}

String planLabel(UserPlan p) => switch (p) {
      UserPlan.free => 'free',
      UserPlan.premium => 'premium',
      UserPlan.aiNanny => 'ai_nanny',
    };

class AdminUserRow {
  AdminUserRow({
    required this.uid,
    required this.name,
    required this.email,
    required this.plan,
    required this.status,
    required this.createdAt,
    required this.lastLoginAt,
    required this.babyName,
    required this.memoriesCount,
    required this.publicMemoriesCount,
    required this.countryCode,
    required this.localeCountry,
  });

  final String uid;
  final String name;
  final String email;
  final UserPlan plan;
  final UserStatus status;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final String babyName;
  final int memoriesCount;
  final int publicMemoriesCount;
  /// País detectado no app (ideal: 2 letras, ex.: BR).
  final String countryCode;
  /// Locale do dispositivo reportado (ex.: pt-BR, en-US). Pode vir sem país.
  final String localeCountry;
}

/// Resultado de uma página (cursor Firestore).
class AdminPaginatedResult<T> {
  const AdminPaginatedResult({
    required this.items,
    required this.hasMore,
    this.lastDocument,
  });

  final List<T> items;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
}

class DashboardStats {
  const DashboardStats({
    this.totalUsers = 0,
    this.activeUsers = 0,
    this.premiumUsers = 0,
    this.freeUsers = 0,
    this.aiNannyUsers = 0,
    this.suspendedUsers = 0,
    this.newUsersThisWeek = 0,
    this.totalBabies = 0,
    this.totalMemories = 0,
    this.totalPublicMemories = 0,
    this.weeklyWinnerName = '—',
  });

  final int totalUsers;
  final int activeUsers;
  final int premiumUsers;
  final int freeUsers;
  final int aiNannyUsers;
  final int suspendedUsers;
  final int newUsersThisWeek;
  final int totalBabies;
  final int totalMemories;
  final int totalPublicMemories;
  final String weeklyWinnerName;
}

class FamilyDetails {
  FamilyDetails({
    required this.uid,
    required this.profile,
    required this.babies,
    required this.memoriesCount,
    required this.reportsCount,
    required this.publicMemoriesCount,
    required this.weeklySubmissions,
  });

  final String uid;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> babies;
  final int memoriesCount;
  final int reportsCount;
  final int publicMemoriesCount;
  final int weeklySubmissions;
}

class PublicMemoryRow {
  PublicMemoryRow({
    required this.id,
    required this.photoUrl,
    required this.babyId,
    required this.badgeId,
    required this.babyName,
    required this.userName,
    required this.email,
    required this.description,
    required this.submissionWeek,
    required this.visibility,
    required this.likes,
    required this.createdAt,
    required this.userId,
    required this.hidden,
    required this.inappropriate,
  });

  final String id;
  final String photoUrl;
  final String babyId;
  final String badgeId;
  final String babyName;
  final String userName;
  final String email;
  final String description;
  final String submissionWeek;
  final String visibility;
  final int likes;
  final DateTime? createdAt;
  final String userId;
  final bool hidden;
  final bool inappropriate;
}

DateTime? tsToDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// Texto da denúncia — aceita vários nomes de campo no Firestore.
String reportMessageFromMap(Map<String, dynamic> d) {
  for (final key in [
    'message',
    'reportMessage',
    'report_message',
    'body',
    'text',
    'reason',
    'mensagem',
  ]) {
    final v = d[key];
    if (v is String) {
      final t = v.trim();
      if (t.isNotEmpty) return t;
    }
  }
  return '';
}

class WeeklySpotlight {
  WeeklySpotlight({
    required this.weekId,
    required this.active,
    required this.babyName,
    required this.userName,
    required this.email,
    required this.photoUrl,
    required this.babyId,
    required this.badgeId,
    required this.badgeTitle,
    required this.publicMemoryId,
    required this.userId,
    required this.drawnAt,
    required this.displayUntil,
  });

  final String weekId;
  final bool active;
  final String babyName;
  final String userName;
  final String email;
  final String photoUrl;
  final String babyId;
  final String badgeId;
  final String badgeTitle;
  final String publicMemoryId;
  final String userId;
  final DateTime? drawnAt;
  final DateTime? displayUntil;

  factory WeeklySpotlight.fromMap(Map<String, dynamic> d) {
    final status = (d['status'] as String?)?.trim().toLowerCase();
    return WeeklySpotlight(
      weekId: '${d['weekId'] ?? d['week_id'] ?? '—'}',
      active: status != 'inactive',
      babyName: (d['winner_baby_display_name'] as String?) ??
          (d['winnerBabyDisplayName'] as String?) ??
          '—',
      userName: (d['winner_owner_name'] as String?) ?? '—',
      email: (d['winner_email'] as String?) ?? '',
      photoUrl: photoFromMap(d),
      babyId: (d['winner_baby_id'] as String?)?.trim() ?? '',
      badgeId: (d['winner_badge_id'] as String?)?.trim() ?? '',
      badgeTitle: (d['winner_badge_title'] as String?) ?? '',
      publicMemoryId: (d['winner_public_memory_id'] as String?) ?? '',
      userId: (d['winner_user_id'] as String?) ?? '',
      drawnAt: tsToDate(d['drawAt'] ?? d['draw_at']),
      displayUntil: tsToDate(d['display_until'] ?? d['displayUntil']),
    );
  }
}

class WeeklyCandidate {
  WeeklyCandidate({
    required this.memoryId,
    required this.userId,
    required this.photoUrl,
    required this.babyId,
    required this.badgeId,
    required this.babyName,
    required this.userName,
    required this.email,
    required this.title,
    required this.submittedAt,
    required this.likes,
    required this.eligible,
  });

  final String memoryId;
  final String userId;
  final String photoUrl;
  final String babyId;
  final String badgeId;
  final String babyName;
  final String userName;
  final String email;
  final String title;
  final DateTime? submittedAt;
  final int likes;
  final bool eligible;

  factory WeeklyCandidate.fromMap(String id, Map<String, dynamic> d) {
    final hidden = d['adminHidden'] == true || d['visibility'] == 'hidden';
    final bad = d['inappropriate'] == true;
    final week = '${d['submissionWeekId'] ?? d['weekId'] ?? ''}'.trim();
    return WeeklyCandidate(
      memoryId: id,
      userId: (d['userId'] as String?) ?? (d['owner_uid'] as String?) ?? '',
      photoUrl: photoFromMap(d),
      babyId: (d['babyId'] as String?)?.trim() ?? '',
      badgeId: (d['badgeId'] as String?)?.trim() ?? '',
      babyName: (d['babyDisplayName'] as String?) ?? '—',
      userName: (d['ownerName'] as String?) ?? '—',
      email: (d['ownerEmail'] as String?) ?? '',
      title: (d['publicDescription'] as String?) ?? (d['description'] as String?) ?? '',
      submittedAt: tsToDate(d['publicEnabledAt'] ?? d['createdAt']),
      likes: (d['likeCount'] as num?)?.toInt() ?? 0,
      eligible: !hidden && !bad && week.isNotEmpty,
    );
  }
}

class WeeklyPhotoReportRow {
  WeeklyPhotoReportRow({
    required this.id,
    required this.publicMemoryId,
    required this.reporterUid,
    required this.reporterEmail,
    required this.message,
    required this.photoUrl,
    required this.targetUserId,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedByEmail,
  });

  final String id;
  final String publicMemoryId;
  final String reporterUid;
  final String reporterEmail;
  final String message;
  final String photoUrl;
  final String targetUserId;
  final String status;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? reviewedByEmail;

  bool get isOpen => status == 'open';

  factory WeeklyPhotoReportRow.fromDoc(
    String id,
    Map<String, dynamic> d,
  ) {
    return WeeklyPhotoReportRow(
      id: id,
      publicMemoryId: (d['publicMemoryId'] as String?)?.trim() ?? '',
      reporterUid: (d['reporterUid'] as String?)?.trim() ?? '',
      reporterEmail: (d['reporterEmail'] as String?)?.trim() ?? '',
      message: reportMessageFromMap(d),
      photoUrl: (d['photoUrl'] as String?)?.trim() ?? '',
      targetUserId: (d['targetUserId'] as String?)?.trim() ?? '',
      status: (d['status'] as String?)?.trim() ?? 'open',
      createdAt: tsToDate(d['createdAt']),
      reviewedAt: tsToDate(d['reviewedAt']),
      reviewedByEmail: (d['reviewedByEmail'] as String?)?.trim(),
    );
  }
}

class AdminAuditLogRow {
  AdminAuditLogRow({
    required this.id,
    required this.adminUid,
    required this.adminEmail,
    required this.action,
    required this.targetUserUid,
    required this.targetUserEmail,
    required this.details,
    required this.createdAt,
  });

  final String id;
  final String adminUid;
  final String adminEmail;
  final String action;
  final String targetUserUid;
  final String targetUserEmail;
  final String details;
  final DateTime? createdAt;
}
