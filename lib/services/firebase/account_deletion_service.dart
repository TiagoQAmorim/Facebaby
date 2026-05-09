import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_database.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

/// Fluxo terminou apenas porque o Firebase exige credencial mais recente; o utilizador deve reautenticar **sem** novo login manual.
class AccountDeletionRequiresRecentLogin implements Exception {
  AccountDeletionRequiresRecentLogin();
}

class AccountDeletionService {
  AccountDeletionService._();

  static final AccountDeletionService instance = AccountDeletionService._();

  /// Elimina dados na nuvem e em seguida o utilizador Firebase Auth + cache local.
  ///
  /// Se `user.delete()` falhar por [requires-recent-login], **não** faz sign-out nem limpa BD local —
  /// permite reautenticar e completar com [deleteFirebaseAuthAndLocalOnly].
  Future<void> deleteAllUserDataAndAccount() async {
    if (kIsWeb) {
      // Web uses a different local persistence story; still allow cloud delete.
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Usuário não autenticado');
    final uid = user.uid;

    await _deleteCloudData(uid);

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AccountDeletionRequiresRecentLogin();
      }
      rethrow;
    }

    await _signOutAndWipeLocal();
  }

  /// Apenas após reautenticar bem-sucedida, quando os dados cloud já foram apagados.
  Future<void> deleteFirebaseAuthAndLocalOnly() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Usuário não autenticado');
    try {
      await user.reload();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AccountDeletionRequiresRecentLogin();
      }
      rethrow;
    }
    await _signOutAndWipeLocal();
  }

  Future<void> _signOutAndWipeLocal() async {
    await AuthService.instance.signOut();
    try {
      await AppDatabase.instance.wipeLocalCache();
    } catch (_) {}
  }

  Future<void> _deleteCloudData(String uid) async {
    final fs = FirestoreService.instance;

    final babies = await fs.listBabies();
    for (final b in babies) {
      final id = (b['id'] as String?)?.trim();
      if (id == null || id.isEmpty) continue;
      await _deleteBabyTree(id);
    }

    await _deleteAllInCollection(fs.eventsCol());

    try {
      await StorageService.instance.deleteFolder('users/$uid');
    } catch (_) {}

    try {
      await fs.userDoc().delete();
    } catch (_) {}
  }

  Future<void> _deleteBabyTree(String babyId) async {
    final fs = FirestoreService.instance;

    await _deleteEventsForBaby(fs, babyId);

    await fs.deleteBaby(babyId);
  }

  Future<void> _deleteAllInCollection(CollectionReference<Map<String, dynamic>> col) async {
    while (true) {
      final snap = await col.limit(250).get();
      if (snap.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteEventsForBaby(FirestoreService fs, String babyId) async {
    while (true) {
      final snap = await fs.eventsCol().where('baby_id', isEqualTo: babyId).limit(250).get();
      if (snap.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }
}
