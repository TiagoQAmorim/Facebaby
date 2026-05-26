import '../models/baby_memory.dart';
import '../utils/weekly_photo_schedule.dart';
import 'app_database.dart';
import 'firebase/firestore_user_repository.dart';
import 'firebase/memory_cloud_sync.dart';

class MemoryService {
  final AppDatabase db;

  const MemoryService(this.db);

  Future<List<BabyMemory>> listForBaby(int babyId) async {
    final rows = await db.listBabyMemories(babyId: babyId);
    return rows.map(BabyMemory.fromRow).where((m) => m.badgeId.isNotEmpty).toList();
  }

  Future<int> upsert(BabyMemory m) async {
    final hasPhoto =
        (m.photoB64 != null && m.photoB64!.trim().isNotEmpty) || (m.photoUrl != null && m.photoUrl!.trim().isNotEmpty);
    final eligible = WeeklyPhotoSchedule.showParticipatingBadge(
      isPublic: m.isPublic,
      hasPhoto: hasPhoto,
      publicEnabledAt: m.publicEnabledAt,
      now: DateTime.now(),
    );

    final babyRow = await db.getBabyById(m.babyId);
    final babyCloud = (babyRow?['cloud_id'] as String?)?.trim();
    if (babyCloud != null && babyCloud.isNotEmpty) {
      await FirestoreUserRepository.instance.clearMemoryBadgeDeletion(
        babyCloudId: babyCloud,
        badgeId: m.badgeId,
      );
    }

    final id = await db.upsertBabyMemory(
      babyId: m.babyId,
      badgeId: m.badgeId,
      title: m.title,
      photoB64: m.photoB64,
      photoUrl: m.photoUrl,
      description: m.description,
      memoryDate: m.memoryDate,
      babyAgeAtMoment: m.babyAgeAtMoment,
      weightAtMoment: m.weightAtMoment,
      heightAtMoment: m.heightAtMoment,
      moodAtMoment: m.moodAtMoment,
      motherNotes: m.motherNotes,
      isFavorite: m.isFavorite,
      isPublic: m.isPublic,
      publicEnabledAt: m.publicEnabledAt,
      publicDisabledAt: m.publicDisabledAt,
      eligibleForWeeklyPhoto: eligible,
      weeklyPhotoWinner: m.weeklyPhotoWinner,
      weeklyPhotoWeekId: m.weeklyPhotoWeekId,
      showBabyFirstNameWhenPublic: m.showBabyFirstNameWhenPublic,
    );
    await MemoryCloudSync.pushBadgeMemory(localBabyId: m.babyId, badgeId: m.badgeId);
    return id;
  }

  Future<void> deleteByBadge({
    required int babyId,
    required String badgeId,
  }) async {
    // Nuvem primeiro: tombstone + apagar evento antes de limpar o SQLite.
    await MemoryCloudSync.deleteBadgeMemory(
        localBabyId: babyId, badgeId: badgeId);
    await db.deleteBabyMemoryByBadge(babyId: babyId, badgeId: badgeId);
  }
}
