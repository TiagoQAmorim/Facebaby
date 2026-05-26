import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Limite diário (50/dia) sincronizado com `ai_usage/{uid}/daily/{yyyyMMdd}`.
class AiUsageLimitsService {
  AiUsageLimitsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const int dailyLimit = 50;

  int _countToday = 0;
  String? _trackedDayKey;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  String _todayKey() => DateFormat('yyyyMMdd').format(DateTime.now());

  DocumentReference<Map<String, dynamic>>? get _dailyRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore
        .collection('ai_usage')
        .doc(uid)
        .collection('daily')
        .doc(_todayKey());
  }

  void startWatching() {
    _sub?.cancel();
    final ref = _dailyRef;
    if (ref == null) return;
    _trackedDayKey = _todayKey();
    _sub = ref.snapshots().listen((snap) {
      final data = snap.data();
      _countToday = _parseCount(data);
    });
  }

  int _parseCount(Map<String, dynamic>? data) {
    if (data == null) return 0;
    final count = data['count'] ?? data['messageCount'];
    if (count is int) return count;
    if (count is num) return count.toInt();
    return int.tryParse('$count') ?? 0;
  }

  void _ensureDay() {
    final key = _todayKey();
    if (_trackedDayKey != key) {
      _trackedDayKey = key;
      _countToday = 0;
      startWatching();
    }
  }

  int get messagesUsedToday {
    _ensureDay();
    return _countToday;
  }

  int get remainingToday {
    _ensureDay();
    return (dailyLimit - _countToday).clamp(0, dailyLimit);
  }

  bool canSendMessage() {
    _ensureDay();
    return _countToday < dailyLimit;
  }

  void applyServerRemaining(int? remaining) {
    if (remaining == null) return;
    _ensureDay();
    _countToday = (dailyLimit - remaining).clamp(0, dailyLimit);
  }

  Future<void> refreshFromServer() async {
    final ref = _dailyRef;
    if (ref == null) return;
    final snap = await ref.get();
    _countToday = _parseCount(snap.data());
  }

  void dispose() {
    _sub?.cancel();
  }
}
