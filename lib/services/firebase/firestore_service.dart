import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_user_repository.dart';

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance = FirestoreService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Usuário não autenticado');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> userDoc() => _db.collection('users').doc(_uid);

  // ---------------- New schema ----------------
  CollectionReference<Map<String, dynamic>> babiesCol() => userDoc().collection('babies');
  CollectionReference<Map<String, dynamic>> eventsCol() => userDoc().collection('events');

  void _log(String op, String path, [Object? extra]) {
    final msg = 'Firestore op=$op uid=$_uid path=$path';
    // ignore: avoid_print
    print(extra == null ? msg : '$msg extra=$extra');
  }

  // Profile helpers (users/{uid})
  Future<Map<String, dynamic>?> getProfile() => FirestoreUserRepository.instance.getUserProfile(_uid);

  Future<void> upsertProfile(Map<String, dynamic> patch) =>
      FirestoreUserRepository.instance.saveUserProfile(_uid, patch);

  // ---------------- Babies CRUD ----------------
  Future<String> createBaby({
    required String name,
    String? sex,
    DateTime? birthDate,
    String? zodiacSign,
    double? weightKg,
    double? heightCm,
    String? photoUrl,
  }) async {
    // Keep snake_case keys to match existing local hydration helpers.
    return FirestoreUserRepository.instance.saveBaby(_uid, {
      'name': name.trim(),
      'sex': sex,
      'birth_date': birthDate?.toIso8601String(),
      'zodiac_sign': zodiacSign,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'photo_url': photoUrl,
    });
  }

  Stream<List<Map<String, dynamic>>> watchBabies({String? motherId}) {
    Query<Map<String, dynamic>> q = babiesCol();
    return q.orderBy('createdAt', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(growable: false);
    });
  }

  Future<List<Map<String, dynamic>>> listBabies({String? motherId}) async {
    Query<Map<String, dynamic>> q = babiesCol();
    final snap = await q.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(growable: false);
  }

  Future<void> updateBaby(String babyId, Map<String, dynamic> patch) async {
    await FirestoreUserRepository.instance.saveBaby(_uid, {'id': babyId, ...patch});
  }

  Future<void> deleteBaby(String babyId) async {
    await babiesCol().doc(babyId).delete();
  }

  Query<Map<String, dynamic>> _eventsForBabyBase(String babyId) {
    // Avoid composite-index requirement.
    // Even (where baby_id == X) + orderBy(event_time) can require an index in some projects.
    // We'll fetch and sort client-side.
    return eventsCol().where('baby_id', isEqualTo: babyId);
  }

  Future<List<Map<String, dynamic>>> _listEventsForBaby(String babyId, String type) async {
    _log('query', 'users/$_uid/events', {'baby_id': babyId, 'type': type, 'indexed': false});
    final snap = await _eventsForBabyBase(babyId).get();
    final rows = snap.docs
        .where((d) => (d.data()['type'] ?? '').toString() == type)
        .map((d) => {'id': d.id, ...d.data()})
        .toList(growable: false);

    int compare(Map<String, dynamic> a, Map<String, dynamic> b) {
      DateTime? dt(dynamic v) {
        if (v is Timestamp) return v.toDate();
        if (v is String) return DateTime.tryParse(v);
        return null;
      }

      final ad = dt(a['event_time']) ?? dt(a['occurred_at']) ?? dt(a['changed_at']) ?? dt(a['ended_at']) ?? dt(a['measured_at']);
      final bd = dt(b['event_time']) ?? dt(b['occurred_at']) ?? dt(b['changed_at']) ?? dt(b['ended_at']) ?? dt(b['measured_at']);
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad); // desc
    }

    rows.sort(compare);
    return rows;
  }

  // ---------------- Events (users/{uid}/events) ----------------

  Future<void> deleteEvent(String eventId) async {
    final id = eventId.trim();
    if (id.isEmpty) return;
    final path = 'users/$_uid/events/$id';
    _log('delete', path);
    await eventsCol().doc(id).delete();
  }
  Future<String> createConsultation({
    required String babyId,
    required String title,
    required DateTime occurredAt,
    String? notes,
    String? phone,
    String? address,
  }) async {
    final ref = eventsCol().doc();
    final path = 'users/$_uid/events/${ref.id}';
    _log('create', path, 'consultation');
    await ref.set({
      'type': 'consultation',
      'baby_id': babyId,
      'event_time': Timestamp.fromDate(occurredAt),
      'occurred_at': occurredAt.toIso8601String(),
      'title': title.trim(),
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      'address': address?.trim().isEmpty == true ? null : address?.trim(),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> updateConsultation({
    required String babyId,
    required String consultationId,
    required Map<String, dynamic> patch,
  }) async {
    final ref = eventsCol().doc(consultationId);
    final path = 'users/$_uid/events/$consultationId';
    _log('update', path, patch.keys.toList(growable: false));
    await ref.set({
      ...patch,
      'type': 'consultation',
      'baby_id': babyId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> listConsultations(String babyId) async {
    return _listEventsForBaby(babyId, 'consultation');
  }

  Future<String> createVaccine({
    required String babyId,
    required String name,
    String? dose,
    DateTime? appliedAt,
    DateTime? nextDueAt,
    String? notes,
  }) async {
    final ref = eventsCol().doc();
    final when = appliedAt ?? DateTime.now();
    final path = 'users/$_uid/events/${ref.id}';
    _log('create', path, 'vaccine');
    await ref.set({
      'type': 'vaccine',
      'baby_id': babyId,
      'event_time': Timestamp.fromDate(when),
      'name': name.trim(),
      'dose': dose?.trim().isEmpty == true ? null : dose?.trim(),
      'applied_at': appliedAt?.toIso8601String(),
      'next_due_at': nextDueAt?.toIso8601String(),
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> updateVaccine({
    required String babyId,
    required String vaccineId,
    required Map<String, dynamic> patch,
  }) async {
    final path = 'users/$_uid/events/$vaccineId';
    _log('update', path, patch.keys.toList(growable: false));
    await eventsCol().doc(vaccineId).set({
      ...patch,
      'type': 'vaccine',
      'baby_id': babyId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> listVaccines(String babyId) async {
    return _listEventsForBaby(babyId, 'vaccine');
  }

  Future<void> upsertMemoryByBadge({
    required String babyId,
    required String badgeId,
    required Map<String, dynamic> data,
  }) async {
    final id = 'badge_${babyId}_$badgeId';
    final path = 'users/$_uid/events/$id';
    _log('set(merge)', path, {'type': 'memory_badge', 'badge_id': badgeId});
    await eventsCol().doc(id).set({
      ...data,
      'type': 'memory_badge',
      'baby_id': babyId,
      'badge_id': badgeId,
      'event_time': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> listMemoriesByBadge(String babyId) async {
    return _listEventsForBaby(babyId, 'memory_badge');
  }

  Future<String> createFeeding({
    required String babyId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSec,
    String? side,
    String? type,
    double? quantityMl,
    String? note,
  }) async {
    final ref = eventsCol().doc();
    final path = 'users/$_uid/events/${ref.id}';
    _log('create', path, 'feeding');
    await ref.set({
      'type': 'feeding',
      'baby_id': babyId,
      'event_time': Timestamp.fromDate(endedAt),
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt.toIso8601String(),
      'duration_sec': durationSec,
      'side': side?.trim().isEmpty == true ? null : side?.trim(),
      'feeding_type': type?.trim().isEmpty == true ? null : type?.trim(),
      'quantity_ml': quantityMl,
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> updateFeeding({
    required String babyId,
    required String feedingId,
    required Map<String, dynamic> patch,
  }) async {
    final path = 'users/$_uid/events/$feedingId';
    _log('update', path, patch.keys.toList(growable: false));
    await eventsCol().doc(feedingId).set({
      ...patch,
      'type': 'feeding',
      'baby_id': babyId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> listFeedings(String babyId) async {
    return _listEventsForBaby(babyId, 'feeding');
  }

  Future<String> createDiaper({
    required String babyId,
    required DateTime changedAt,
    required String kind,
    String? note,
  }) async {
    final ref = eventsCol().doc();
    final path = 'users/$_uid/events/${ref.id}';
    _log('create', path, 'diaper');
    await ref.set({
      'type': 'diaper',
      'baby_id': babyId,
      'event_time': Timestamp.fromDate(changedAt),
      'changed_at': changedAt.toIso8601String(),
      'kind': kind,
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> updateDiaper({
    required String babyId,
    required String diaperId,
    required Map<String, dynamic> patch,
  }) async {
    final path = 'users/$_uid/events/$diaperId';
    _log('update', path, patch.keys.toList(growable: false));
    await eventsCol().doc(diaperId).set({
      ...patch,
      'type': 'diaper',
      'baby_id': babyId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> listDiapers(String babyId) async {
    return _listEventsForBaby(babyId, 'diaper');
  }

  Future<String> createSleepRecord({
    required String babyId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSec,
    String? quality,
    String? note,
  }) async {
    final ref = eventsCol().doc();
    final path = 'users/$_uid/events/${ref.id}';
    _log('create', path, 'sleep');
    await ref.set({
      'type': 'sleep',
      'baby_id': babyId,
      'event_time': Timestamp.fromDate(endedAt),
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt.toIso8601String(),
      'duration_sec': durationSec,
      'quality': quality?.trim().isEmpty == true ? null : quality?.trim(),
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> updateSleepRecord({
    required String babyId,
    required String sleepId,
    required Map<String, dynamic> patch,
  }) async {
    final path = 'users/$_uid/events/$sleepId';
    _log('update', path, patch.keys.toList(growable: false));
    await eventsCol().doc(sleepId).set({
      ...patch,
      'type': 'sleep',
      'baby_id': babyId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> listSleepRecords(String babyId) async {
    return _listEventsForBaby(babyId, 'sleep');
  }

  Future<String> createGrowthRecord({
    required String babyId,
    required String kind,
    required double value,
    required DateTime measuredAt,
  }) async {
    final ref = eventsCol().doc();
    final path = 'users/$_uid/events/${ref.id}';
    _log('create', path, 'growth');
    await ref.set({
      'type': 'growth',
      'baby_id': babyId,
      'event_time': Timestamp.fromDate(measuredAt),
      'kind': kind,
      'value': value,
      'measured_at': measuredAt.toIso8601String(),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> updateGrowthRecord({
    required String babyId,
    required String growthId,
    required Map<String, dynamic> patch,
  }) async {
    final path = 'users/$_uid/events/$growthId';
    _log('update', path, patch.keys.toList(growable: false));
    await eventsCol().doc(growthId).set({
      ...patch,
      'type': 'growth',
      'baby_id': babyId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> listGrowthRecords(String babyId) async {
    return _listEventsForBaby(babyId, 'growth');
  }

  Future<String> createSymptomReport({
    required String babyId,
    required DateTime occurredAt,
    String? medicationNote,
    required bool fever,
    double? tempCelsius,
    required bool crying,
    required bool pain,
    required bool colic,
    required bool reflux,
    String? otherNote,
  }) async {
    final ref = eventsCol().doc();
    final path = 'users/$_uid/events/${ref.id}';
    _log('create', path, 'symptom_report');
    final med = medicationNote?.trim();
    final other = otherNote?.trim();
    await ref.set({
      'type': 'symptom_report',
      'baby_id': babyId,
      'event_time': Timestamp.fromDate(occurredAt),
      'occurred_at': occurredAt.toIso8601String(),
      'medication_note': (med == null || med.isEmpty) ? null : med,
      'fever': fever,
      'temp_celsius': tempCelsius,
      'crying': crying,
      'pain': pain,
      'colic': colic,
      'reflux': reflux,
      'other_note': (other == null || other.isEmpty) ? null : other,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> updateSymptomReport({
    required String babyId,
    required String symptomReportId,
    required DateTime occurredAt,
    String? medicationNote,
    required bool fever,
    double? tempCelsius,
    required bool crying,
    required bool pain,
    required bool colic,
    required bool reflux,
    String? otherNote,
  }) async {
    final path = 'users/$_uid/events/$symptomReportId';
    _log('update', path, 'symptom_report');
    final med = medicationNote?.trim();
    final other = otherNote?.trim();
    await eventsCol().doc(symptomReportId).set({
      'type': 'symptom_report',
      'baby_id': babyId,
      'event_time': Timestamp.fromDate(occurredAt),
      'occurred_at': occurredAt.toIso8601String(),
      'medication_note': (med == null || med.isEmpty) ? null : med,
      'fever': fever,
      'temp_celsius': tempCelsius,
      'crying': crying,
      'pain': pain,
      'colic': colic,
      'reflux': reflux,
      'other_note': (other == null || other.isEmpty) ? null : other,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> listSymptomReports(String babyId) async {
    return _listEventsForBaby(babyId, 'symptom_report');
  }

  Future<void> upsertDailyJournal({
    required String babyId,
    required String dayKey,
    String? text,
  }) async {
    final id = 'journal_${babyId}_$dayKey';
    final path = 'users/$_uid/events/$id';
    _log('set(merge)', path, 'daily_journal');
    await eventsCol().doc(id).set({
      'type': 'daily_journal',
      'baby_id': babyId,
      'day_key': dayKey,
      'text': text,
      'event_time': Timestamp.fromDate(DateTime.tryParse('${dayKey}T00:00:00') ?? DateTime.now()),
      'updated_at': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> listDailyJournals(String babyId) async {
    return _listEventsForBaby(babyId, 'daily_journal');
  }

  Future<void> upsertDailySummarySnapshot({
    required String babyId,
    required String dayKey,
    required Map<String, dynamic> data,
  }) async {
    final id = 'daily_snapshot_${babyId}_$dayKey';
    final path = 'users/$_uid/events/$id';
    _log('set(merge)', path, 'daily_summary_snapshot');
    await eventsCol().doc(id).set({
      ...data,
      'type': 'daily_summary_snapshot',
      'baby_id': babyId,
      'day_key': dayKey,
      'event_time': Timestamp.fromDate(DateTime.tryParse('${dayKey}T00:00:00') ?? DateTime.now()),
      'updated_at': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> listDailySummarySnapshots(String babyId) async {
    return _listEventsForBaby(babyId, 'daily_summary_snapshot');
  }

  // ---------------- Weekly Photo / public memories (root collections) ----------------

  CollectionReference<Map<String, dynamic>> _publicMemoriesCol() => _db.collection('public_memories');

  CollectionReference<Map<String, dynamic>> _weeklyPhotoContestsCol() => _db.collection('weekly_photo_contests');

  /// Documento sanitizado para mural / sorteio (sem dados médicos).
  Future<void> upsertPublicMemoryDoc({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final path = 'public_memories/$docId';
    _log('set(merge)', path, data.keys.toList(growable: false));
    await _publicMemoriesCol().doc(docId).set({
      ...data,
      'owner_uid': _uid,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deletePublicMemoryDoc(String docId) async {
    final path = 'public_memories/$docId';
    _log('delete', path);
    await _publicMemoriesCol().doc(docId).delete();
  }

  /// Snapshot do destaque atual na Home (`spotlight_current`), preenchido pelas Cloud Functions.
  Stream<DocumentSnapshot<Map<String, dynamic>>> weeklyPhotoSpotlightSnapshots() {
    return _weeklyPhotoContestsCol().doc('spotlight_current').snapshots();
  }

  /// Fallback público para a Home: lista as últimas memórias públicas (ordenadas por
  /// `publicEnabledAt` desc) — usado quando `spotlight_current` está em falta/inativo.
  /// O cliente filtra por `photoUrl != null/vazio` no chamador.
  Stream<QuerySnapshot<Map<String, dynamic>>> publicMemoriesLatestSnapshots({int limit = 20}) {
    return _publicMemoriesCol()
        .orderBy('publicEnabledAt', descending: true)
        .limit(limit)
        .snapshots();
  }
}

