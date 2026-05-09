import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_database.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

/// Espelha perfis de mãe/bebé no Firestore + fotos no Storage (conta autenticada).
/// A BD local mantém-se para eventos e FKs; a cópia na nuvem é a cópia partilhada entre dispositivos.
class ProfileCloudSync {
  ProfileCloudSync._();

  static String _imageExtFromBytes(Uint8List bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
    if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50) return 'png';
    return 'jpg';
  }

  static Future<void> pushMother(int localMotherId) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final r = await AppDatabase.instance.getMotherById(localMotherId);
      if (r == null) return;

      var cid = (r['cloud_id'] as String?)?.trim();
      final name = (r['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return;

      DateTime? birth;
      final bs = r['birth_date'] as String?;
      if (bs != null) birth = DateTime.tryParse(bs);

      final pb = (r['photo_b64'] as String?)?.trim();
      Uint8List? imgBytes;
      if (pb != null && pb.isNotEmpty) {
        try {
          imgBytes = Uint8List.fromList(base64Decode(pb));
        } catch (_) {}
      }

      if (cid == null || cid.isEmpty) {
        // New schema: profile == users/{uid}
        cid = uid;
        await AppDatabase.instance.setMotherCloudId(motherId: localMotherId, cloudId: cid);
      }

      String? photoUrl;
      if (imgBytes != null && imgBytes.isNotEmpty) {
        final ext = _imageExtFromBytes(imgBytes);
        photoUrl = await StorageService.instance.uploadMotherPhotoBytes(
          motherId: cid,
          bytes: imgBytes,
          fileExt: ext,
        );
      }

      await FirestoreService.instance.upsertProfile({
        'name': name,
        'phone': r['phone'],
        'birth_date': birth?.toIso8601String(),
        'height_cm': r['height_cm'],
        'father_height_cm': r['father_height_cm'],
        if (photoUrl != null) 'photo_url': photoUrl,
      });
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await AppDatabase.instance.persistMotherPhotoUrl(motherId: localMotherId, photoUrl: photoUrl);
      }
    } catch (e, st) {
      debugPrint('ProfileCloudSync.pushMother failed: $e\n$st');
      rethrow;
    }
  }

  static Future<void> pushBaby(int localBabyId) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      final b = await AppDatabase.instance.getBabyById(localBabyId);
      if (b == null) return;

      final midLocal = (b['mother_id'] as num).toInt();
      await pushMother(midLocal);

      var cid = (b['cloud_id'] as String?)?.trim();
      final name = (b['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return;

      DateTime? birth;
      final bds = b['birth_date'] as String?;
      if (bds != null) birth = DateTime.tryParse(bds);

      final pb = (b['photo_b64'] as String?)?.trim();
      Uint8List? imgBytes;
      if (pb != null && pb.isNotEmpty) {
        try {
          imgBytes = Uint8List.fromList(base64Decode(pb));
        } catch (_) {}
      }

      if (cid == null || cid.isEmpty) {
        cid = await FirestoreService.instance.createBaby(
          name: name,
          sex: (b['sex'] as String?) ?? 'F',
          birthDate: birth,
          zodiacSign: b['zodiac_sign'] as String?,
          weightKg: b['weight_kg'] as double?,
          heightCm: b['height_cm'] as double?,
          photoUrl: null,
        );
        await AppDatabase.instance.setBabyCloudId(babyId: localBabyId, cloudId: cid);
      }

      String? photoUrl;
      if (imgBytes != null && imgBytes.isNotEmpty) {
        final ext = _imageExtFromBytes(imgBytes);
        photoUrl = await StorageService.instance.uploadBabyPhotoBytes(
          babyId: cid,
          bytes: imgBytes,
          fileExt: ext,
        );
      }

      await FirestoreService.instance.updateBaby(cid, {
        'name': name,
        'sex': (b['sex'] as String?) ?? 'F',
        'birth_date': birth?.toIso8601String(),
        'zodiac_sign': b['zodiac_sign'],
        'weight_kg': b['weight_kg'],
        'height_cm': b['height_cm'],
        if (photoUrl != null) 'photo_url': photoUrl,
      });
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await AppDatabase.instance.persistBabyPhotoUrl(babyId: localBabyId, photoUrl: photoUrl);
      }
    } catch (e, st) {
      debugPrint('ProfileCloudSync.pushBaby failed: $e\n$st');
      rethrow;
    }
  }
}
