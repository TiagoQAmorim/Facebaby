import '../../controllers/current_baby_controller.dart';
import '../../models/ai/ai_profile_model.dart';
import '../../repositories/ai/ai_profile_repository.dart';

/// Salva e carrega o histórico da IA Babá (`ai_profiles/{uid}`).
class AiProfileService {
  AiProfileService({AiProfileRepository? repository})
      : _repository = repository ?? AiProfileRepository.instance;

  final AiProfileRepository _repository;

  Future<AiProfile> load() => _repository.load();

  Stream<AiProfile> watch() => _repository.watch();

  Future<void> saveHistory(String aiHistory) async {
    final babyId = CurrentBabyController.instance.currentBabyCloudId;
    await _repository.save(
      aiHistory: aiHistory,
      babyId: babyId != null && babyId.isNotEmpty ? babyId : null,
    );
  }

  Future<void> clearHistory() => _repository.clear();
}
