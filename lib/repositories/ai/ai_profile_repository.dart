import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/ai/ai_profile_model.dart';

/// `ai_profiles/{userId}` — histórico informado pela família para a IA Babá.
class AiProfileRepository {
  AiProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static final AiProfileRepository instance = AiProfileRepository();

  static const collectionName = 'ai_profiles';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _docRef() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection(collectionName).doc(uid);
  }

  Future<AiProfile> load() async {
    final ref = _docRef();
    if (ref == null) return const AiProfile();
    final snap = await ref.get();
    if (!snap.exists) return const AiProfile();
    return AiProfile.fromFirestore(snap.data());
  }

  Stream<AiProfile> watch() {
    final ref = _docRef();
    if (ref == null) return Stream.value(const AiProfile());
    return ref.snapshots().map((snap) {
      if (!snap.exists) return const AiProfile();
      return AiProfile.fromFirestore(snap.data());
    });
  }

  Future<void> save({
    required String aiHistory,
    String? babyId,
  }) async {
    final ref = _docRef();
    if (ref == null) {
      throw const AiProfileNotSignedInException();
    }
    final trimmed = aiHistory.trim();
    if (trimmed.length > AiProfile.maxHistoryLength) {
      throw AiProfileTooLongException(AiProfile.maxHistoryLength);
    }

    final snap = await ref.get();
    final payload = <String, dynamic>{
      'aiHistory': trimmed,
      'babyId': babyId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!snap.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(payload, SetOptions(merge: true));
  }

  Future<void> clear() async {
    final ref = _docRef();
    if (ref == null) {
      throw const AiProfileNotSignedInException();
    }
    final snap = await ref.get();
    final payload = <String, dynamic>{
      'aiHistory': '',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!snap.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(payload, SetOptions(merge: true));
  }
}

class AiProfileNotSignedInException implements Exception {
  const AiProfileNotSignedInException();
}

class AiProfileTooLongException implements Exception {
  const AiProfileTooLongException(this.maxLength);
  final int maxLength;
}
