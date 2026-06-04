import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../models/admin_models.dart';
import '../utils/admin_photo_loader.dart' show photoFromMap;
import 'admin_audit_service.dart';
import 'admin_auth_service.dart';
import 'admin_permissions.dart';

class AdminRepository {
  AdminRepository._();
  static final AdminRepository instance = AdminRepository._();

  final _db = FirebaseFirestore.instance;

  String get _adminUid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Admin não autenticado');
    }
    return uid;
  }

  void _requireManage() =>
      AdminPermissions.requireManageUsers(AdminAuthService.instance.admin);

  Future<String?> _userEmail(String uid) async {
    if (uid.isEmpty) return null;
    final snap = await _db.collection('users').doc(uid).get();
    return (snap.data()?['email'] as String?)?.trim();
  }

  Future<Map<String, dynamic>?> _publicMemoryData(String id) async {
    final snap = await _db.collection('public_memories').doc(id).get();
    if (!snap.exists) return null;
    return snap.data();
  }

  Future<bool> _userProfileExists(String uid) async {
    if (uid.trim().isEmpty) return false;
    return (await _db.collection('users').doc(uid).get()).exists;
  }

  /// `public_memories/{uid}_{babyId}_{badgeId}` — UID no id quando campos falham.
  String _resolvePublicMemoryOwnerUid(
    String docId,
    Map<String, dynamic> data,
  ) {
    final fromFields =
        '${data['userId'] ?? data['owner_uid'] ?? data['ownerUid'] ?? data['user_id'] ?? ''}'
            .trim();
    if (fromFields.isNotEmpty) return fromFields;
    final i = docId.indexOf('_');
    if (i <= 0) return '';
    return docId.substring(0, i).trim();
  }

  /// Só órfão quando o UID está identificado e `users/{uid}` não existe.
  /// Sem UID resolvido não apaga nem oculta (evita perda por formato antigo).
  Future<bool> _isOrphanPublicMemory(String docId, Map<String, dynamic> data) async {
    final uid = _resolvePublicMemoryOwnerUid(docId, data);
    if (uid.isEmpty) return false;
    return !await _userProfileExists(uid);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _runOrderedQuery({
    required CollectionReference<Map<String, dynamic>> col,
    required List<String> orderFields,
    required bool descending,
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Object? lastError;
    for (final field in orderFields) {
      try {
        Query<Map<String, dynamic>> q =
            col.orderBy(field, descending: descending).limit(limit);
        if (startAfter != null) {
          q = q.startAfterDocument(startAfter);
        }
        return await q.get();
      } catch (e) {
        lastError = e;
        debugPrint('AdminRepository._runOrderedQuery $field: $e');
      }
    }
    try {
      Query<Map<String, dynamic>> q = col
          .orderBy(FieldPath.documentId, descending: descending)
          .limit(limit);
      if (startAfter != null) {
        q = q.startAfterDocument(startAfter);
      }
      return await q.get();
    } catch (e) {
      lastError = e;
    }
    throw StateError('Ordered query failed: $lastError');
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _queryPublicMemories({
    int limit = 200,
    bool descending = true,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    return _runOrderedQuery(
      col: _db.collection('public_memories'),
      orderFields: const ['updated_at', 'publicEnabledAt', 'createdAt'],
      descending: descending,
      limit: limit,
      startAfter: startAfter,
    );
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _queryUsers({
    required int limit,
    required bool descending,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    return _runOrderedQuery(
      col: _db.collection('users'),
      orderFields: const ['createdAt', 'created_at', 'lastLoginAt', 'last_login_at'],
      descending: descending,
      limit: limit,
      startAfter: startAfter,
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _pageDocs(
    QuerySnapshot<Map<String, dynamic>> snap,
    int pageSize,
  ) {
    final docs = snap.docs;
    if (docs.length <= pageSize) return docs;
    return docs.take(pageSize).toList();
  }

  bool _pageHasMore(QuerySnapshot<Map<String, dynamic>> snap, int pageSize) =>
      snap.docs.length > pageSize;

  Future<void> _deleteOrphanPublicMemory(String docId) async {
    if (docId.trim().isEmpty) return;
    _requireManage();
    final ref = _db.collection('public_memories').doc(docId);
    while (true) {
      final likes = await ref.collection('likes').limit(200).get();
      if (likes.docs.isEmpty) break;
      final batch = _db.batch();
      for (final d in likes.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    await ref.delete();
  }

  /// Remove `public_memories` cujo `users/{uid}` já não existe (conta apagada).
  Future<int> purgeOrphanPublicMemories({int maxScan = 600}) async {
    _requireManage();
    var removed = 0;
    var scanned = 0;
    DocumentSnapshot<Map<String, dynamic>>? last;
    while (scanned < maxScan) {
      Query<Map<String, dynamic>> q = _db
          .collection('public_memories')
          .orderBy(FieldPath.documentId)
          .limit(100);
      if (last != null) {
        q = q.startAfterDocument(last);
      }
      final snap = await q.get();
      if (snap.docs.isEmpty) break;
      for (final doc in snap.docs) {
        scanned++;
        if (await _isOrphanPublicMemory(doc.id, doc.data())) {
          await _deleteOrphanPublicMemory(doc.id);
          removed++;
        }
      }
      last = snap.docs.last;
      if (snap.docs.length < 100) break;
    }
    return removed;
  }

  Future<List<AdminAuditLogRow>> fetchAuditLogs({int limit = 500}) =>
      AdminAuditService.instance.fetchLogs(limit: limit);

  Future<List<AdminUserRow>> fetchUsers({int limit = 500}) async {
    final page = await fetchUsersPage(
      pageSize: limit,
      newestFirst: true,
    );
    return page.items;
  }

  Future<AdminPaginatedResult<AdminUserRow>> fetchUsersPage({
    int pageSize = 10,
    bool newestFirst = true,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final snap = await _queryUsers(
      limit: pageSize + 1,
      descending: newestFirst,
      startAfter: startAfter,
    );
    final pageDocs = _pageDocs(snap, pageSize);
    final rows = <AdminUserRow>[];
    for (final doc in pageDocs) {
      rows.add(_userRowFromDocLight(doc));
    }
    return AdminPaginatedResult(
      items: rows,
      hasMore: _pageHasMore(snap, pageSize),
      lastDocument: pageDocs.isEmpty ? null : pageDocs.last,
    );
  }

  AdminUserRow _userRowFromDocLight(DocumentSnapshot<Map<String, dynamic>> doc) {
    final uid = doc.id;
    final d = doc.data() ?? {};
    String normalizeCountry(Object? raw) {
      final c = '${raw ?? ''}'.trim().toUpperCase();
      return c.length == 2 ? c : '';
    }

    String deriveCountryCode(Map<String, dynamic> data) {
      final direct = normalizeCountry(
        data['countryCode'] ?? data['country_code'] ?? data['appCountry'],
      );
      if (direct.isNotEmpty) return direct;
      final locale = '${data['localeCountry'] ?? data['locale_country'] ?? ''}'.trim();
      if (locale.contains('_')) {
        final part = locale.split('_').last;
        final cc = normalizeCountry(part);
        if (cc.isNotEmpty) return cc;
      }
      if (locale.contains('-')) {
        final part = locale.split('-').last;
        final cc = normalizeCountry(part);
        if (cc.isNotEmpty) return cc;
      }
      return normalizeCountry(locale);
    }

    final localeCountry =
        '${d['localeCountry'] ?? d['locale_country'] ?? ''}'.trim();
    final countryCode = deriveCountryCode(d);
    final babyName =
        '${d['selectedBabyName'] ?? d['selected_baby_name'] ?? d['babyName'] ?? ''}'.trim();
    return AdminUserRow(
      uid: uid,
      name: (d['name'] as String?)?.trim().isNotEmpty == true
          ? (d['name'] as String).trim()
          : (d['displayName'] as String?)?.trim() ?? '—',
      email: (d['email'] as String?) ?? '',
      plan: planFromData(d),
      status: statusFromData(d),
      createdAt: tsToDate(d['createdAt'] ?? d['created_at']),
      lastLoginAt: tsToDate(d['lastLoginAt'] ?? d['last_login_at']),
      babyName: babyName.isEmpty ? '—' : babyName,
      memoriesCount: -1,
      publicMemoriesCount: -1,
      countryCode: countryCode,
      localeCountry: localeCountry,
    );
  }

  Future<DashboardStats> fetchDashboardStats() async {
    final result = await _functions.httpsCallable('adminGetDashboardStats').call();
    final data = result.data;
    if (data is! Map) {
      throw StateError('Resposta inválida do servidor');
    }
    final m = Map<String, dynamic>.from(data);
    return DashboardStats(
      totalUsers: (m['totalUsers'] as num?)?.toInt() ?? 0,
      activeUsers: (m['activeUsers'] as num?)?.toInt() ?? 0,
      premiumUsers: (m['premiumUsers'] as num?)?.toInt() ?? 0,
      freeUsers: (m['freeUsers'] as num?)?.toInt() ?? 0,
      aiNannyUsers: (m['aiNannyUsers'] as num?)?.toInt() ?? 0,
      suspendedUsers: (m['suspendedUsers'] as num?)?.toInt() ?? 0,
      newUsersThisWeek: (m['newUsersThisWeek'] as num?)?.toInt() ?? 0,
      totalPublicMemories: (m['totalPublicMemories'] as num?)?.toInt() ?? 0,
      aiCallsToday: (m['aiCallsToday'] as num?)?.toInt() ?? 0,
      aiTokensToday: (m['aiTokensToday'] as num?)?.toInt() ?? 0,
      weeklyWinnerName: '${m['weeklyWinnerName'] ?? '—'}',
    );
  }

  Future<AiUsageStats> fetchAiUsageStats({String? dateKey, int topLimit = 50}) async {
    final result = await _functions.httpsCallable('adminGetAiUsageStats').call({
      if (dateKey != null && dateKey.isNotEmpty) 'dateKey': dateKey,
      'topLimit': topLimit,
    });
    final data = result.data;
    if (data is! Map) {
      throw StateError('Resposta inválida do servidor');
    }
    return AiUsageStats.fromMap(Map<String, dynamic>.from(data));
  }

  Future<UserAiUsageStats> fetchUserAiUsage(String uid, {String? dateKey}) async {
    final result = await _functions.httpsCallable('adminGetUserAiUsage').call({
      'uid': uid,
      if (dateKey != null && dateKey.isNotEmpty) 'dateKey': dateKey,
    });
    final data = result.data;
    if (data is! Map) {
      throw StateError('Resposta inválida do servidor');
    }
    return UserAiUsageStats.fromMap(Map<String, dynamic>.from(data));
  }

  Future<FamilyDetails> fetchFamily(String uid) async {
    final profile = (await _db.collection('users').doc(uid).get()).data() ?? {};
    final babies = await _db.collection('users').doc(uid).collection('babies').get();
    final memCount = await _db
        .collection('users')
        .doc(uid)
        .collection('events')
        .where('type', isEqualTo: 'memory_badge')
        .count()
        .get();
    final repCount = await _db
        .collection('users')
        .doc(uid)
        .collection('events')
        .where('type', isEqualTo: 'symptom_report')
        .count()
        .get();
    final pubQ = await _db.collection('public_memories').where('userId', isEqualTo: uid).get();
    final weekSub = pubQ.docs.where((d) {
      final w = d.data()['submissionWeekId'] ?? d.data()['submission_week_id'];
      return w != null && '$w'.isNotEmpty;
    }).length;
    return FamilyDetails(
      uid: uid,
      profile: profile,
      babies: babies.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
      memoriesCount: memCount.count ?? 0,
      reportsCount: repCount.count ?? 0,
      publicMemoriesCount: pubQ.docs.length,
      weeklySubmissions: weekSub,
    );
  }

  Future<void> suspendUser({
    required String uid,
    String? reason,
  }) async {
    _requireManage();
    await _db.collection('users').doc(uid).set({
      'status': 'suspended',
      'suspendedAt': FieldValue.serverTimestamp(),
      'suspendedBy': _adminUid,
      if (reason != null && reason.trim().isNotEmpty) 'suspensionReason': reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final email = await _userEmail(uid);
    await AdminAuditService.instance.log(
      action: AdminAuditAction.suspendUser,
      targetUserUid: uid,
      targetUserEmail: email,
      details: reason != null && reason.trim().isNotEmpty ? reason.trim() : null,
    );
  }

  Future<void> reactivateUser(String uid) async {
    _requireManage();
    await _db.collection('users').doc(uid).set({
      'status': 'active',
      'suspendedAt': FieldValue.delete(),
      'suspendedBy': FieldValue.delete(),
      'suspensionReason': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final email = await _userEmail(uid);
    await AdminAuditService.instance.log(
      action: AdminAuditAction.reactivateUser,
      targetUserUid: uid,
      targetUserEmail: email,
    );
  }

  Future<void> setUserPlan(String uid, UserPlan plan) async {
    _requireManage();
    final patch = _planPatch(plan);
    await _db.collection('users').doc(uid).set(patch, SetOptions(merge: true));
    final email = await _userEmail(uid);
    await AdminAuditService.instance.log(
      action: AdminAuditAction.changePlan,
      targetUserUid: uid,
      targetUserEmail: email,
      details: planLabel(plan),
    );
  }

  /// Altera o plano / tipo de acesso de vários usuários de uma vez.
  Future<void> setUserPlansBulk(List<String> uids, UserPlan plan) async {
    _requireManage();
    final unique = uids.map((u) => u.trim()).where((u) => u.isNotEmpty).toSet();
    if (unique.isEmpty) return;
    final patch = _planPatch(plan);
    for (final uid in unique) {
      await _db.collection('users').doc(uid).set(patch, SetOptions(merge: true));
      final email = await _userEmail(uid);
      await AdminAuditService.instance.log(
        action: AdminAuditAction.changePlan,
        targetUserUid: uid,
        targetUserEmail: email,
        details: 'bulk:${planLabel(plan)}',
      );
    }
  }

  Map<String, dynamic> _planPatch(UserPlan plan) {
    final patch = <String, dynamic>{
      'adminPlan': planLabel(plan),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (plan == UserPlan.premium) {
      patch['premiumLifetime'] = true;
    } else if (plan == UserPlan.free) {
      patch['premiumLifetime'] = false;
      patch['adminPlan'] = 'free';
    }
    return patch;
  }

  Future<List<PublicMemoryRow>> fetchPublicMemories({int limit = 200}) async {
    final page = await fetchPublicMemoriesPage(
      pageSize: limit,
      newestFirst: true,
    );
    return page.items;
  }

  Future<AdminPaginatedResult<PublicMemoryRow>> fetchPublicMemoriesPage({
    int pageSize = 10,
    bool newestFirst = true,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final snap = await _queryPublicMemories(
      limit: pageSize + 1,
      descending: newestFirst,
      startAfter: startAfter,
    );
    final out = <PublicMemoryRow>[];
    for (final doc in _pageDocs(snap, pageSize)) {
      if (await _isOrphanPublicMemory(doc.id, doc.data())) {
        debugPrint(
          'AdminRepository.fetchPublicMemoriesPage: skip orphan ${doc.id}',
        );
        continue;
      }
      out.add(_publicRow(doc));
    }
    final pageDocs = _pageDocs(snap, pageSize);
    return AdminPaginatedResult(
      items: out,
      hasMore: _pageHasMore(snap, pageSize),
      lastDocument: pageDocs.isEmpty ? null : pageDocs.last,
    );
  }

  PublicMemoryRow _publicRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final hidden = d['adminHidden'] == true || d['visibility'] == 'hidden';
    final bad = d['inappropriate'] == true;
    final uid = _resolvePublicMemoryOwnerUid(doc.id, d);
    return PublicMemoryRow(
      id: doc.id,
      photoUrl: photoFromMap(d),
      babyId: (d['babyId'] as String?)?.trim() ?? '',
      badgeId: (d['badgeId'] as String?)?.trim() ?? '',
      babyName: (d['babyDisplayName'] as String?) ?? '—',
      userName: (d['ownerName'] as String?) ?? '—',
      email: (d['ownerEmail'] as String?) ?? '',
      description: (d['publicDescription'] as String?) ??
          (d['description'] as String?) ??
          '',
      submissionWeek: '${d['submissionWeekId'] ?? d['weekId'] ?? '—'}',
      visibility: hidden ? 'hidden' : (bad ? 'inappropriate' : 'visible'),
      likes: (d['likeCount'] as num?)?.toInt() ?? (d['like_count'] as num?)?.toInt() ?? 0,
      createdAt: tsToDate(d['createdAt'] ?? d['publicEnabledAt'] ?? d['updated_at']),
      userId: uid.isNotEmpty
          ? uid
          : ((d['userId'] as String?) ?? (d['owner_uid'] as String?) ?? ''),
      hidden: hidden,
      inappropriate: bad,
    );
  }

  Future<void> hidePublicMemory(String id, {bool inappropriate = false}) async {
    _requireManage();
    final before = await _publicMemoryData(id);
    final userId =
        (before?['userId'] as String?) ?? (before?['owner_uid'] as String?) ?? '';
    final userEmail = (before?['ownerEmail'] as String?) ?? await _userEmail(userId);

    await _db.collection('public_memories').doc(id).set({
      'adminHidden': true,
      'visibility': 'hidden',
      if (inappropriate) 'inappropriate': true,
      'hiddenAt': FieldValue.serverTimestamp(),
      'hiddenBy': _adminUid,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await AdminAuditService.instance.log(
      action: inappropriate
          ? AdminAuditAction.hideInappropriateContent
          : AdminAuditAction.removePublicMemory,
      targetUserUid: userId,
      targetUserEmail: userEmail,
      details: 'publicMemoryId=$id',
    );
  }

  Future<void> markInappropriate(String id) async {
    await hidePublicMemory(id, inappropriate: true);
  }

  Future<void> restorePublicMemory(String id) async {
    _requireManage();
    await _db.collection('public_memories').doc(id).set({
      'adminHidden': false,
      'visibility': 'visible',
      'inappropriate': false,
      'hiddenAt': FieldValue.delete(),
      'hiddenBy': FieldValue.delete(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<WeeklySpotlight?> fetchWeeklySpotlight() async {
    final snap = await _db.collection('weekly_photo_contests').doc('spotlight_current').get();
    if (!snap.exists) return null;
    var data = Map<String, dynamic>.from(snap.data() ?? {});
    final winnerUid =
        '${data['winner_user_id'] ?? data['winnerUserId'] ?? ''}'.trim();
    if (winnerUid.isNotEmpty && !await _userProfileExists(winnerUid)) {
      await _db.collection('weekly_photo_contests').doc('spotlight_current').delete();
      return null;
    }
    final memId = (data['winner_public_memory_id'] as String?)?.trim() ?? '';
    if (memId.isNotEmpty) {
      final mem = await _db.collection('public_memories').doc(memId).get();
      if (!mem.exists) {
        await _db.collection('weekly_photo_contests').doc('spotlight_current').delete();
        return null;
      }
      if (mem.data() != null) {
        final m = mem.data()!;
        if (await _isOrphanPublicMemory(memId, m)) {
          await _deleteOrphanPublicMemory(memId);
          await _db.collection('weekly_photo_contests').doc('spotlight_current').delete();
          return null;
        }
        if (photoFromMap(data).isEmpty) {
          data['winner_photo_url'] = photoFromMap(m);
        }
        data.putIfAbsent('winner_baby_id', () => m['babyId']);
        data.putIfAbsent('winner_badge_id', () => m['badgeId']);
        data.putIfAbsent('winner_user_id', () => m['userId'] ?? m['owner_uid']);
        final liveName = (m['babyDisplayName'] as String?)?.trim();
        if (liveName != null && liveName.isNotEmpty) {
          data['winner_baby_display_name'] = liveName;
        }
        final liveSex = (m['babySex'] as String?)?.trim().toUpperCase();
        if (liveSex == 'M' || liveSex == 'F') {
          data['winner_baby_sex'] = liveSex;
        }
      }
    }
    return WeeklySpotlight.fromMap(data);
  }

  Future<List<WeeklyCandidate>> fetchWeeklyCandidates({int limit = 150}) async {
    final page = await fetchWeeklyCandidatesPage(
      pageSize: limit,
      newestFirst: true,
    );
    return page.items;
  }

  Future<AdminPaginatedResult<WeeklyCandidate>> fetchWeeklyCandidatesPage({
    int pageSize = 10,
    bool newestFirst = true,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final snap = await _queryPublicMemories(
      limit: pageSize + 1,
      descending: newestFirst,
      startAfter: startAfter,
    );
    final out = <WeeklyCandidate>[];
    for (final doc in _pageDocs(snap, pageSize)) {
      final data = doc.data();
      if (await _isOrphanPublicMemory(doc.id, data)) {
        debugPrint(
          'AdminRepository.fetchWeeklyCandidatesPage: skip orphan ${doc.id}',
        );
        continue;
      }
      out.add(WeeklyCandidate.fromMap(doc.id, data));
    }
    final pageDocs = _pageDocs(snap, pageSize);
    return AdminPaginatedResult(
      items: out,
      hasMore: _pageHasMore(snap, pageSize),
      lastDocument: pageDocs.isEmpty ? null : pageDocs.last,
    );
  }

  Future<void> setWeeklyWinner(String publicMemoryId, String userId) async {
    _requireManage();
    final mem = await _db.collection('public_memories').doc(publicMemoryId).get();
    if (!mem.exists) throw StateError('Memória pública não encontrada');
    final d = mem.data();
    if (d == null) throw StateError('Memória pública sem dados');
    final weekId = '${d['submissionWeekId'] ?? d['weekId'] ?? ''}'.trim();
    final targetUid = (d['userId'] as String?) ?? (d['owner_uid'] as String?) ?? userId;
    final targetEmail = (d['ownerEmail'] as String?) ?? await _userEmail(targetUid);

    await _db.collection('weekly_photo_contests').doc('spotlight_current').set({
      'status': 'active',
      'weekId': weekId.isEmpty ? null : weekId,
      'winner_public_memory_id': publicMemoryId,
      'winner_memory_id': d['memoryId'] ?? publicMemoryId,
      'winner_user_id': targetUid,
      'winner_photo_url': photoFromMap(d),
      'winner_baby_id': d['babyId'],
      'winner_badge_id': d['badgeId'],
      'winner_badge_title': d['badgeTitle'] ?? '',
      'winner_baby_display_name': d['babyDisplayName'],
      'winner_public_description': d['publicDescription'] ?? d['description'],
      'drawAt': FieldValue.serverTimestamp(),
      'display_until': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await AdminAuditService.instance.log(
      action: AdminAuditAction.selectWeeklyPhotoWinner,
      targetUserUid: targetUid,
      targetUserEmail: targetEmail,
      details: 'weekId=$weekId; publicMemoryId=$publicMemoryId',
    );
  }

  Future<void> removeWeeklyWinner() async {
    _requireManage();
    await _db.collection('weekly_photo_contests').doc('spotlight_current').delete();
  }

  Future<List<WeeklyPhotoReportRow>> fetchWeeklyPhotoReports({
    int limit = 200,
  }) async {
    _requireManage();
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _db
          .collection('weekly_photo_reports')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
    } catch (_) {
      snap = await _db.collection('weekly_photo_reports').limit(limit).get();
    }
    final rows = snap.docs
        .map((d) => WeeklyPhotoReportRow.fromDoc(d.id, d.data()))
        .toList();
    rows.sort((a, b) {
      final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return rows;
  }

  Future<void> markWeeklyPhotoReportReviewed(String reportId) async {
    _requireManage();
    final id = reportId.trim();
    if (id.isEmpty) return;
    final adminEmail =
        AdminAuthService.instance.admin?.email ??
        FirebaseAuth.instance.currentUser?.email ??
        '';
    await _db.collection('weekly_photo_reports').doc(id).update({
      'status': 'reviewed',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedByUid': _adminUid,
      'reviewedByEmail': adminEmail,
    });
  }

  Future<void> hidePublicMemoryFromReport({
    required String reportId,
    required String publicMemoryId,
    bool inappropriate = true,
  }) async {
    await hidePublicMemory(publicMemoryId, inappropriate: inappropriate);
    await markWeeklyPhotoReportReviewed(reportId);
  }

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  Future<int> previewBroadcastAudience(Map<String, dynamic> targeting) async {
    _requireManage();
    final result = await _functions
        .httpsCallable('previewAdminBroadcastAudience')
        .call({'targeting': targeting});
    final data = result.data;
    if (data is Map) {
      final c = data['count'];
      if (c is int) return c;
      if (c is num) return c.toInt();
    }
    return 0;
  }

  /// Limpa mensagens de teste no balão: ignora antigas + purge local nos apps + desativa campanhas ativas.
  Future<int> resetBubbleQueueForAllUsers() async {
    _requireManage();
    final now = FieldValue.serverTimestamp();
    final generation = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _db.collection('floating_message_settings').doc('global').set(
      {
        'resetBefore': now,
        'localQueueGeneration': generation,
        'updatedAt': now,
        'updatedBy': _adminUid,
      },
      SetOptions(merge: true),
    );

    var deactivated = 0;
    while (true) {
      final activeSnap = await _db
          .collection('floating_messages')
          .where('active', isEqualTo: true)
          .limit(200)
          .get();
      if (activeSnap.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in activeSnap.docs) {
        batch.update(doc.reference, {
          'active': false,
          'deactivatedAt': now,
          'deactivatedReason': 'global_bubble_reset',
        });
      }
      await batch.commit();
      deactivated += activeSnap.docs.length;
      if (activeSnap.docs.length < 200) break;
    }

    await AdminAuditService.instance.log(
      action: AdminAuditAction.publishBroadcast,
      targetUserUid: 'broadcast',
      targetUserEmail: '—',
      details:
          'bubble_queue_reset generation=$generation deactivated=$deactivated',
    );

    return deactivated;
  }

  Future<Map<String, dynamic>> publishBroadcast({
    required String text,
    required Map<String, dynamic> targeting,
    String? title,
    String? messageType,
    int? priority,
    String? targetAudience,
    String? startsAtIso,
    String? endsAtIso,
    String? actionRoute,
    String? imageBase64,
    String? imageUrl,
    String? imageAlt,
    double? imageAspectRatio,
    String? dismissMode,
    bool critical = false,
    String? actionUrl,
    String? actionButtonLabel,
  }) async {
    _requireManage();
    final link = actionUrl?.trim() ?? '';
    final btnLabel = actionButtonLabel?.trim() ?? '';
    final route = actionRoute?.trim() ?? '';
    final t = title?.trim() ?? '';
    final result = await _functions.httpsCallable('publishAdminBroadcast').call({
      'text': text.trim(),
      'targeting': targeting,
      if (t.isNotEmpty) 'title': t,
      if (messageType != null && messageType.trim().isNotEmpty)
        'messageType': messageType.trim(),
      if (priority != null) 'priority': priority,
      if (targetAudience != null && targetAudience.trim().isNotEmpty)
        'targetAudience': targetAudience.trim(),
      if (startsAtIso != null && startsAtIso.isNotEmpty) 'startsAt': startsAtIso,
      if (endsAtIso != null && endsAtIso.isNotEmpty) 'endsAt': endsAtIso,
      if (route.isNotEmpty) 'actionRoute': route,
      if (imageBase64 != null && imageBase64.isNotEmpty)
        'imageBase64': imageBase64,
      if (imageUrl != null && imageUrl.trim().isNotEmpty)
        'imageUrl': imageUrl.trim(),
      if (imageAlt != null && imageAlt.trim().isNotEmpty)
        'imageAlt': imageAlt.trim(),
      if (imageAspectRatio != null) 'imageAspectRatio': imageAspectRatio,
      if (dismissMode != null && dismissMode.trim().isNotEmpty)
        'dismissMode': dismissMode.trim(),
      if (critical) 'critical': true,
      if (link.isNotEmpty) 'actionUrl': link,
      if (btnLabel.isNotEmpty) 'actionButtonLabel': btnLabel,
    });
    final data = result.data;
    if (data is! Map) {
      throw StateError('Resposta inválida do servidor');
    }
    final count = data['recipientCount'];
    await AdminAuditService.instance.log(
      action: AdminAuditAction.publishBroadcast,
      targetUserUid: 'broadcast',
      targetUserEmail: '—',
      details:
          'recipients=${count ?? '?'} type=${targeting['type'] ?? 'all'}',
    );
    return Map<String, dynamic>.from(data);
  }

  Future<String> forceWeeklyDraw({String? secret}) async {
    _requireManage();
    const fromEnv = String.fromEnvironment('FORCE_WEEKLY_DRAW_URL');
    final pid = DefaultFirebaseOptions.web.projectId;
    final uri = fromEnv.isNotEmpty
        ? Uri.parse(fromEnv)
        : Uri.parse(
            'https://southamerica-east1-$pid.cloudfunctions.net/forceWeeklyPhotoDraw');
    final resp = await http.post(
      uri,
      headers: {
        if (secret != null && secret.isNotEmpty) 'x-force-secret': secret,
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('Sorteio falhou (${resp.statusCode}): ${resp.body}');
    }
    return resp.body;
  }
}
