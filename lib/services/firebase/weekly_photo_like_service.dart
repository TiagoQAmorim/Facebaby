import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import 'firestore_service.dart';

/// Curtidas na memória pública vencedora da Foto da Semana (`public_memories/{id}/likes/{uid}`).
class WeeklyPhotoLikeService {
  WeeklyPhotoLikeService._();

  static final WeeklyPhotoLikeService instance = WeeklyPhotoLikeService._();

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Estado agregado para UI (contagem + se o utilizador atual já curtiu).
  static Stream<WeeklyPhotoLikeState> watch(String publicMemoryId) {
    final id = publicMemoryId.trim();
    if (id.isEmpty) {
      return Stream.value(const WeeklyPhotoLikeState(count: 0, likedByMe: false));
    }
    final likes = FirestoreService.instance.publicMemoryLikesCol(id);
    final uid = _uid;
    if (uid == null) {
      return likes.snapshots().map(
        (snap) => WeeklyPhotoLikeState(count: snap.docs.length, likedByMe: false),
      );
    }
    return likes.snapshots().map((snap) {
      final likedByMe = snap.docs.any((d) => d.id == uid);
      return WeeklyPhotoLikeState(count: snap.docs.length, likedByMe: likedByMe);
    });
  }

  /// Returns `true` if a curtida foi criada ou removida.
  /// `false` quando não há utilizador Firebase autenticado ou [publicMemoryId] vazio (sem chamada ao Firestore).
  Future<bool> toggleLike(String publicMemoryId) async {
    final memoryId = publicMemoryId.trim();
    if (memoryId.isEmpty) {
      if (kDebugMode) {
        debugPrint('[WeeklyPhotoLike] blocked: empty memoryId');
      }
      return false;
    }

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (kDebugMode) {
      debugPrint('[WeeklyPhotoLike] LIKE memoryId: $memoryId');
      debugPrint('[WeeklyPhotoLike] LIKE auth uid: $uid');
    }
    if (user == null || uid == null || uid.isEmpty) {
      if (kDebugMode) {
        debugPrint('[WeeklyPhotoLike] blocked: no Firebase Auth session');
      }
      return false;
    }

    if (kDebugMode) {
      debugPrint('[WeeklyPhotoLike] LIKE doc uid: $uid (must equal auth uid)');
    }

    final ref =
        FirestoreService.instance.publicMemoryLikesCol(memoryId).doc(uid);
    try {
      final snap = await ref.get(const GetOptions(source: Source.server));
      if (snap.exists) {
        await ref.delete();
      } else {
        // Regras Firestore: apenas a chave `createdAt` — sem merge, sem campos extra.
        await ref.set(
          <String, dynamic>{
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      }
    } on FirebaseException catch (e, st) {
      if (kDebugMode) {
        debugPrint(
            '[WeeklyPhotoLike] FirebaseException ${e.code}: ${e.message}');
        debugPrint('$st');
      }
      rethrow;
    }
    return true;
  }
}

class WeeklyPhotoLikeState {
  final int count;
  final bool likedByMe;

  const WeeklyPhotoLikeState({required this.count, required this.likedByMe});
}
