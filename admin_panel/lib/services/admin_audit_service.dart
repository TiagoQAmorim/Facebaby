import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/admin_models.dart';
import 'admin_auth_service.dart';

/// Firestore collection: `admin_logs`
abstract final class AdminAuditAction {
  static const adminLogin = 'admin_login';
  static const suspendUser = 'suspend_user';
  static const reactivateUser = 'reactivate_user';
  static const changePlan = 'change_plan';
  static const removePublicMemory = 'remove_public_memory';
  static const selectWeeklyPhotoWinner = 'select_weekly_photo_winner';
  static const hideInappropriateContent = 'hide_inappropriate_content';
  static const publishBroadcast = 'publish_broadcast';

  static const all = [
    adminLogin,
    suspendUser,
    reactivateUser,
    changePlan,
    removePublicMemory,
    selectWeeklyPhotoWinner,
    hideInappropriateContent,
    publishBroadcast,
  ];
}

String adminAuditActionLabel(String action) => switch (action) {
      AdminAuditAction.adminLogin => 'Admin login',
      AdminAuditAction.suspendUser => 'Suspend user',
      AdminAuditAction.reactivateUser => 'Reactivate user',
      AdminAuditAction.changePlan => 'Change plan',
      AdminAuditAction.removePublicMemory => 'Remove public memory',
      AdminAuditAction.selectWeeklyPhotoWinner => 'Weekly photo winner',
      AdminAuditAction.hideInappropriateContent => 'Hide inappropriate',
      AdminAuditAction.publishBroadcast => 'Publish broadcast',
      _ => action,
    };

class AdminAuditService {
  AdminAuditService._();
  static final AdminAuditService instance = AdminAuditService._();

  final _db = FirebaseFirestore.instance;

  Future<void> log({
    required String action,
    String? targetUserUid,
    String? targetUserEmail,
    String? details,
  }) async {
    final profile = AdminAuthService.instance.admin;
    final user = FirebaseAuth.instance.currentUser;
    final adminUid = profile?.uid ?? user?.uid;
    if (adminUid == null || adminUid.isEmpty) return;

    final adminEmail = profile?.email ?? user?.email ?? '';

    await _db.collection('admin_logs').add({
      'adminUid': adminUid,
      'adminEmail': adminEmail,
      'action': action,
      'targetUserUid': targetUserUid ?? '',
      'targetUserEmail': targetUserEmail ?? '',
      'details': details ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<AdminAuditLogRow>> fetchLogs({int limit = 500}) async {
    final snap = await _db
        .collection('admin_logs')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((doc) {
      final d = doc.data();
      return AdminAuditLogRow(
        id: doc.id,
        adminUid: (d['adminUid'] as String?) ?? '',
        adminEmail: (d['adminEmail'] as String?) ?? '',
        action: (d['action'] as String?) ?? '',
        targetUserUid: (d['targetUserUid'] as String?) ?? '',
        targetUserEmail: (d['targetUserEmail'] as String?) ?? '',
        details: (d['details'] as String?) ?? '',
        createdAt: tsToDate(d['createdAt']),
      );
    }).toList();
  }
}
