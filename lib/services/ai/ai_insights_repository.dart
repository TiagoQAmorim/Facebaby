import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/ai/ai_insight_model.dart';
import 'ai_insight_local_engine.dart';

/// Cache Firestore: `ai_insights/{uid}/daily|weekly/{id}`.
class AiInsightsRepository {
  AiInsightsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? _dailyRef(String dayKey) {
    final uid = _uid;
    if (uid == null) return null;
    return _db
        .collection('ai_insights')
        .doc(uid)
        .collection('daily')
        .doc(dayKey);
  }

  DocumentReference<Map<String, dynamic>>? _weeklyRef(String weekKey) {
    final uid = _uid;
    if (uid == null) return null;
    return _db
        .collection('ai_insights')
        .doc(uid)
        .collection('weekly')
        .doc(weekKey);
  }

  Future<AiInsight?> loadDaily(String dayKey) async {
    final ref = _dailyRef(dayKey);
    if (ref == null) return null;
    final snap = await ref.get();
    if (!snap.exists) return null;
    return AiInsight.fromFirestore(
      snap.id,
      snap.data() ?? {},
      kind: AiInsightKind.dailySummary,
    );
  }

  Future<AiInsight?> loadWeekly(String weekKey) async {
    final ref = _weeklyRef(weekKey);
    if (ref == null) return null;
    final snap = await ref.get();
    if (!snap.exists) return null;
    return AiInsight.fromFirestore(
      snap.id,
      snap.data() ?? {},
      kind: AiInsightKind.weeklySummary,
    );
  }

  Future<void> saveLocal(AiInsight insight) async {
    final data = insight.toFirestoreLocal();
    final ref = switch (insight.kind) {
      AiInsightKind.dailySummary => _dailyRef(insight.id),
      AiInsightKind.weeklySummary => _weeklyRef(insight.id),
      _ => null,
    };
    if (ref == null) return;
    await ref.set(data, SetOptions(merge: true));
  }

  Stream<AiInsight?> watchDaily(String dayKey) {
    final ref = _dailyRef(dayKey);
    if (ref == null) return Stream.value(null);
    return ref.snapshots().map((snap) {
      if (!snap.exists) return null;
      return AiInsight.fromFirestore(
        snap.id,
        snap.data() ?? {},
        kind: AiInsightKind.dailySummary,
      );
    });
  }
}
