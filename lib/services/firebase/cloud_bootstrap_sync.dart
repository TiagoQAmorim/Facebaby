import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_database.dart';
import 'firestore_service.dart';
import 'firestore_user_repository.dart';
import 'memory_cloud_sync.dart';

/// Baixa dados do Firestore e re-hidrata o SQLite local (cache).
///
/// Objetivo: impedir “sumiu tudo” quando o app reinicia ou o SQLite falha
/// e tornar o Firestore a fonte de verdade.
class CloudBootstrapSync {
  CloudBootstrapSync._();

  static bool get _authed => FirebaseAuth.instance.currentUser != null;
  static DateTime? _lastProfilesHydrateAt;
  /// Por bebê local — o cooldown global anterior fazia saltar a hidratação de memórias/fotos dos outros filhos.
  static final Map<int, DateTime> _lastBabyHydrateAtByLocalId = {};

  /// Quando há bebês no SQLite mas algum `mother_id` aponta para uma mãe inexistente,
  /// recria a mãe a partir de `users/{uid}` e reencaminha o FK de todos os bebês afetados.
  ///
  /// Isto corrige «Meu Perfil › Mãe sem informações» após inconsistência na BD local.
  static Future<bool> repairOrphanMotherLinks() async {
    if (!_authed || kIsWeb) return false;
    try {
      final babies = await AppDatabase.instance.listBabies();
      var canonicalMotherId = 0;
      var changed = false;
      for (final row in babies) {
        final bid = (row['id'] as num?)?.toInt();
        final mid = (row['mother_id'] as num?)?.toInt();
        if (bid == null || mid == null) continue;
        final mRow = await AppDatabase.instance.getMotherById(mid);
        if (mRow != null) continue;

        if (canonicalMotherId <= 0) {
          canonicalMotherId = await _ensureMotherFromProfileFirestore();
        }
        if (canonicalMotherId <= 0) break;

        await AppDatabase.instance.patchBabyMotherId(babyId: bid, motherId: canonicalMotherId);
        changed = true;
      }
      return changed;
    } catch (e, st) {
      debugPrint('CloudBootstrapSync.repairOrphanMotherLinks failed: $e\n$st');
      return false;
    }
  }

  static Map<String, Object?> _motherDataFromProfile(Map<String, dynamic>? profile) {
    final motherName =
        ((profile?['name'] ?? profile?['displayName'] ?? '').toString()).trim();
    return {
      'name': motherName.isEmpty ? 'Mãe' : motherName,
      'phone': profile?['phone'],
      'birth_date': profile?['birth_date'] ?? profile?['birthDate'],
      'height_cm': profile?['height_cm'] ?? profile?['heightCm'],
      'father_height_cm': profile?['father_height_cm'] ?? profile?['fatherHeightCm'],
      'father_name': profile?['father_name'] ?? profile?['fatherName'],
      'father_birth_date':
          profile?['father_birth_date'] ?? profile?['fatherBirthDate'],
      'register_father': profile?['register_father'] ?? profile?['registerFather'],
      'show_family_christian':
          profile?['show_family_christian'] ?? profile?['showFamilyChristian'],
      'show_family_horoscope':
          profile?['show_family_horoscope'] ?? profile?['showFamilyHoroscope'],
      'show_family_spiritist':
          profile?['show_family_spiritist'] ?? profile?['showFamilySpiritist'],
      'show_family_jewish':
          profile?['show_family_jewish'] ?? profile?['showFamilyJewish'],
      'photo_url': profile?['photo_url'] ?? profile?['photoUrl'],
      'father_photo_url':
          profile?['father_photo_url'] ?? profile?['fatherPhotoUrl'],
    };
  }

  static Future<int> _ensureMotherFromProfileFirestore() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final profile = await FirestoreService.instance.getProfile();
    return AppDatabase.instance.upsertMotherFromCloud(
      cloudId: uid,
      data: _motherDataFromProfile(profile),
    );
  }

  /// Se o SQLite estiver vazio mas o usuário estiver logado, baixa mãe/bebê do Firestore
  /// e recria localmente (mantendo `cloud_id` para futuras sincronizações).
  static Future<void> hydrateProfilesIfMissing() async {
    if (!_authed || kIsWeb) return;
    try {
      final now = DateTime.now();
      if (_lastProfilesHydrateAt != null && now.difference(_lastProfilesHydrateAt!) < const Duration(seconds: 25)) {
        return;
      }
      _lastProfilesHydrateAt = now;

      final localBabies = await AppDatabase.instance.listBabies();
      if (localBabies.isNotEmpty) return;

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final profile = await FirestoreService.instance.getProfile();
      final babies = await FirestoreService.instance.listBabies();

      // Local DB still needs a mother row for FK, but cloud profile is users/{uid}.
      final localMotherId = await AppDatabase.instance.upsertMotherFromCloud(
        cloudId: uid,
        data: _motherDataFromProfile(profile),
      );
      if (localMotherId == 0) return;

      for (final b in babies) {
        final bid = (b['id'] as String?)?.trim();
        if (bid == null || bid.isEmpty) continue;
        await AppDatabase.instance.upsertBabyFromCloud(
          cloudId: bid,
          localMotherId: localMotherId,
          data: {
            ...b,
            // Support both new (camelCase) and old (snake_case) field names.
            'birth_date': b['birth_date'] ?? b['birthDate'],
            'zodiac_sign': b['zodiac_sign'] ?? b['zodiacSign'],
            'weight_kg': b['weight_kg'] ?? b['weightKg'],
            'height_cm': b['height_cm'] ?? b['heightCm'],
            'photo_url': b['photo_url'] ?? b['photoUrl'],
          },
        );
      }
    } catch (e, st) {
      debugPrint('CloudBootstrapSync.hydrateProfilesIfMissing failed: $e\n$st');
    }
  }

  /// Garante que o bebê selecionado na nuvem existe no SQLite.
  /// Retorna o id local (SQLite) se conseguiu.
  static Future<int?> ensureSelectedBabyCached({required String selectedBabyCloudId}) async {
    if (!_authed || kIsWeb) return null;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final cloudId = selectedBabyCloudId.trim();
    if (cloudId.isEmpty) return null;

    // 1) Se já existe localmente, ótimo.
    final existingLocalId = await AppDatabase.instance.getLocalBabyIdByCloudId(cloudId);
    if (existingLocalId != null) return existingLocalId;

    // 2) Garante mãe local (FK) a partir do perfil.
    final profile = await FirestoreService.instance.getProfile();
    final localMotherId = await AppDatabase.instance.upsertMotherFromCloud(
      cloudId: uid,
      data: _motherDataFromProfile(profile),
    );
    if (localMotherId == 0) return null;

    // 3) Busca bebê na nuvem e cria localmente.
    final baby = await FirestoreUserRepository.instance.getBaby(uid, cloudId);
    if (baby == null) return null;
    final localId = await AppDatabase.instance.upsertBabyFromCloud(
      cloudId: cloudId,
      localMotherId: localMotherId,
      data: {
        ...baby,
        'birth_date': baby['birth_date'] ?? baby['birthDate'],
        'zodiac_sign': baby['zodiac_sign'] ?? baby['zodiacSign'],
        'weight_kg': baby['weight_kg'] ?? baby['weightKg'],
        'height_cm': baby['height_cm'] ?? baby['heightCm'],
        'photo_url': baby['photo_url'] ?? baby['photoUrl'],
      },
    );
    if (localId == 0) return null;
    return localId;
  }

  /// Baixa do Firestore as coleções do bebê (consultas, vacinas e memórias por badge)
  /// e grava no SQLite local.
  static Future<void> hydrateBabyContent(int localBabyId, {bool bypassThrottle = false}) async {
    if (!_authed || kIsWeb) return;
    try {
      final now = DateTime.now();
      if (!bypassThrottle) {
        final prev = _lastBabyHydrateAtByLocalId[localBabyId];
        if (prev != null && now.difference(prev) < const Duration(seconds: 20)) {
          return;
        }
      }
      _lastBabyHydrateAtByLocalId[localBabyId] = now;

      final baby = await AppDatabase.instance.getBabyById(localBabyId);
      final babyCloud = (baby?['cloud_id'] as String?)?.trim();
      if (babyCloud == null || babyCloud.isEmpty) return;

      final cRows = await FirestoreService.instance.listConsultations(babyCloud);
      for (final c in cRows) {
        await AppDatabase.instance.upsertConsultationFromCloud(localBabyId: localBabyId, data: c);
      }

      final vRows = await FirestoreService.instance.listVaccines(babyCloud);
      for (final v in vRows) {
        await AppDatabase.instance.upsertVaccineFromCloud(localBabyId: localBabyId, data: v);
      }

      final deletedBadgeIds =
          await FirestoreUserRepository.instance.listDeletedBadgeIdsForBaby(
        babyCloud,
      );
      if (deletedBadgeIds.isNotEmpty) {
        await AppDatabase.instance.applyCloudMemoryDeletions(
          localBabyId: localBabyId,
          babyCloudId: babyCloud,
          badgeIds: deletedBadgeIds,
        );
      }

      final mRows = await FirestoreService.instance.listMemoriesByBadge(babyCloud);
      for (final m in mRows) {
        await AppDatabase.instance.upsertBabyMemoryFromCloud(
            localBabyId: localBabyId, data: m);
      }
      // Remove da BD local selos que o utilizador apagou mas a nuvem ainda devolveu (corrige estado antigo).
      final memories = await AppDatabase.instance.listBabyMemories(
          babyId: localBabyId);
      for (final row in memories) {
        final bid = (row['badge_id'] as String?)?.trim() ?? '';
        if (bid.isEmpty) continue;
        if (await AppDatabase.instance.isBabyMemoryBadgeTombstoned(
            babyId: localBabyId, badgeId: bid)) {
          await AppDatabase.instance.deleteBabyMemoryByBadge(
            babyId: localBabyId,
            badgeId: bid,
          );
          unawaited(MemoryCloudSync.deleteBadgeMemory(
            localBabyId: localBabyId,
            badgeId: bid,
          ));
        }
      }

      final feedRows = await FirestoreService.instance.listFeedings(babyCloud);
      for (final f in feedRows) {
        await AppDatabase.instance.upsertFeedingFromCloud(localBabyId: localBabyId, data: f);
      }

      final diaperRows = await FirestoreService.instance.listDiapers(babyCloud);
      for (final d in diaperRows) {
        await AppDatabase.instance.upsertDiaperFromCloud(localBabyId: localBabyId, data: d);
      }

      final sleepRows = await FirestoreService.instance.listSleepRecords(babyCloud);
      for (final s in sleepRows) {
        await AppDatabase.instance.upsertSleepFromCloud(localBabyId: localBabyId, data: s);
      }

      final growthRows = await FirestoreService.instance.listGrowthRecords(babyCloud);
      for (final g in growthRows) {
        await AppDatabase.instance.upsertGrowthFromCloud(localBabyId: localBabyId, data: g);
      }

      final symptomRows = await FirestoreService.instance.listSymptomReports(babyCloud);
      for (final sr in symptomRows) {
        await AppDatabase.instance.upsertSymptomReportFromCloud(localBabyId: localBabyId, data: sr);
      }

      final journalRows = await FirestoreService.instance.listDailyJournals(babyCloud);
      for (final j in journalRows) {
        await AppDatabase.instance.upsertDailyJournalFromCloud(localBabyId: localBabyId, data: j);
      }

      final snapRows = await FirestoreService.instance.listDailySummarySnapshots(babyCloud);
      for (final ds in snapRows) {
        await AppDatabase.instance.upsertDailySummarySnapshotFromCloud(localBabyId: localBabyId, data: ds);
      }
    } catch (e, st) {
      if (e is FirebaseException) {
        final code = e.code;
        if (code == 'unavailable' || code == 'deadline-exceeded' || code == 'network-request-failed') {
          debugPrint('CloudBootstrapSync.hydrateBabyContent networkError: $code');
          return;
        }
      }
      debugPrint('CloudBootstrapSync.hydrateBabyContent failed: $e\n$st');
    }
  }

  /// Versão “fire-and-forget” para não travar UI.
  static void hydrateBabyContentSoon(int localBabyId) {
    unawaited(hydrateBabyContent(localBabyId));
  }
}

