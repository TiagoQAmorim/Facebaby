import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_database.dart';
import 'firestore_service.dart';
import 'storage_service.dart';
import 'weekly_photo_public_sync.dart';

/// Espelha perfis de mãe/bebê no Firestore + fotos no Storage (conta autenticada).
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
      DateTime? fatherBirth;
      final fbs = r['father_birth_date'] as String?;
      if (fbs != null) fatherBirth = DateTime.tryParse(fbs);
      final registerFather = r['register_father'] == null
          ? null
          : ((r['register_father'] as num?)?.toInt() == 1);

      final pb = (r['photo_b64'] as String?)?.trim();
      Uint8List? imgBytes;
      if (pb != null && pb.isNotEmpty) {
        try {
          imgBytes = Uint8List.fromList(base64Decode(pb));
        } catch (_) {}
      }

      final fpb = (r['father_photo_b64'] as String?)?.trim();
      Uint8List? fatherImgBytes;
      if (fpb != null && fpb.isNotEmpty) {
        try {
          fatherImgBytes = Uint8List.fromList(base64Decode(fpb));
        } catch (_) {}
      }

      if (cid == null || cid.isEmpty) {
        // New schema: profile == users/{uid}
        cid = uid;
        await AppDatabase.instance
            .setMotherCloudId(motherId: localMotherId, cloudId: cid);
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

      String? fatherPhotoUrl;
      if (fatherImgBytes != null && fatherImgBytes.isNotEmpty) {
        final ext = _imageExtFromBytes(fatherImgBytes);
        fatherPhotoUrl = await StorageService.instance.uploadFatherPhotoBytes(
          bytes: fatherImgBytes,
          fileExt: ext,
        );
      }

      await FirestoreService.instance.upsertProfile({
        'name': name,
        'phone': r['phone'],
        'birth_date': birth?.toIso8601String(),
        'height_cm': r['height_cm'],
        'father_name': r['father_name'],
        'father_height_cm': r['father_height_cm'],
        'father_birth_date': fatherBirth?.toIso8601String(),
        'register_father': registerFather,
        'show_family_christian': (r['show_family_christian'] as num?)?.toInt() == 1,
        'show_family_horoscope':
            (r['show_family_horoscope'] as num?)?.toInt() != 0,
        'show_family_spiritist':
            (r['show_family_spiritist'] as num?)?.toInt() == 1,
        'show_family_jewish': (r['show_family_jewish'] as num?)?.toInt() == 1,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (fatherPhotoUrl != null) 'father_photo_url': fatherPhotoUrl,
      });
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await AppDatabase.instance
            .persistMotherPhotoUrl(motherId: localMotherId, photoUrl: photoUrl);
      }
      if (fatherPhotoUrl != null && fatherPhotoUrl.isNotEmpty) {
        await AppDatabase.instance.persistFatherPhotoUrl(
          motherId: localMotherId,
          photoUrl: fatherPhotoUrl,
        );
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
        final birthW = (b['birth_weight_kg'] as num?)?.toDouble();
        final birthH = (b['birth_height_cm'] as num?)?.toDouble();
        final profileW = (b['weight_kg'] as num?)?.toDouble();
        final profileH = (b['height_cm'] as num?)?.toDouble();
        cid = await FirestoreService.instance.createBaby(
          name: name,
          sex: (b['sex'] as String?) ?? 'F',
          birthDate: birth,
          zodiacSign: b['zodiac_sign'] as String?,
          weightKg: profileW,
          heightCm: profileH,
          birthWeightKg: birthW,
          birthHeightCm: birthH,
          firstBaby: _boolFromSqlite(b['first_baby']),
          onboardingConcerns:
              _stringListFromJson(b['onboarding_concerns_json'] as String?),
          onboardingGoals:
              _stringListFromJson(b['onboarding_goals_json'] as String?),
          photoUrl: null,
        );
        await AppDatabase.instance
            .setBabyCloudId(babyId: localBabyId, cloudId: cid);
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

      final birthW = (b['birth_weight_kg'] as num?)?.toDouble();
      final birthH = (b['birth_height_cm'] as num?)?.toDouble();
      // Baseline ao nascer só quando gravado explicitamente — nunca o peso/altura atuais.
      final effectiveBirthW =
          (birthW != null && birthW > 0) ? birthW : null;
      final effectiveBirthH =
          (birthH != null && birthH > 0) ? birthH : null;
      final cloudPatch = <String, dynamic>{
        'name': name,
        'sex': (b['sex'] as String?) ?? 'F',
        'birth_date': birth?.toIso8601String(),
        'zodiac_sign': b['zodiac_sign'],
        'weight_kg': b['weight_kg'],
        'height_cm': b['height_cm'],
        if (effectiveBirthW != null) 'birth_weight_kg': effectiveBirthW,
        if (effectiveBirthH != null) 'birth_height_cm': effectiveBirthH,
        'first_baby': _boolFromSqlite(b['first_baby']),
        'onboarding_concerns':
            _stringListFromJson(b['onboarding_concerns_json'] as String?),
        'onboarding_goals':
            _stringListFromJson(b['onboarding_goals_json'] as String?),
        if (photoUrl != null) 'photo_url': photoUrl,
      };
      await FirestoreService.instance.updateBaby(cid, cloudPatch);
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await AppDatabase.instance
            .persistBabyPhotoUrl(babyId: localBabyId, photoUrl: photoUrl);
      }
      await WeeklyPhotoPublicSync.syncAllPublicMemoriesForBaby(
        localBabyId: localBabyId,
      );
    } catch (e, st) {
      debugPrint('ProfileCloudSync.pushBaby failed: $e\n$st');
      rethrow;
    }
  }

  static bool? _boolFromSqlite(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    return null;
  }

  static List<String>? _stringListFromJson(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded.map((e) => '$e').toList(growable: false);
      }
    } catch (_) {}
    return null;
  }
}
