import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OnboardingDraft {
  final String stage;
  final int step;
  final String babyName;
  final DateTime? birthDate;
  final double? weightKg;
  final double? heightCm;
  final String motherName;
  final DateTime? motherBirthDate;
  final String fatherName;
  final DateTime? fatherBirthDate;
  final double? motherHeightCm;
  final double? fatherHeightCm;
  final String? babyPhotoB64;
  final String? motherPhotoB64;
  final String? fatherPhotoB64;
  final bool? registerFather;
  final String sex;
  final bool? firstBaby;
  final List<String> concerns;
  final List<String> goals;
  /// `christian` | `horoscope` | `spiritist` | `jewish`
  final List<String> familyMessageKinds;
  /// Legado — migrado para [familyMessageKinds] em [fromJson].
  final String? familyMessageChoice;
  final int? localMotherId;
  final int? localBabyId;
  final String aiHistory;

  const OnboardingDraft({
    this.stage = 'welcome',
    this.step = 0,
    this.babyName = '',
    this.birthDate,
    this.weightKg,
    this.heightCm,
    this.motherName = '',
    this.motherBirthDate,
    this.fatherName = '',
    this.fatherBirthDate,
    this.motherHeightCm,
    this.fatherHeightCm,
    this.babyPhotoB64,
    this.motherPhotoB64,
    this.fatherPhotoB64,
    this.registerFather,
    this.sex = '',
    this.firstBaby,
    this.concerns = const [],
    this.goals = const [],
    this.familyMessageKinds = const [],
    this.familyMessageChoice,
    this.localMotherId,
    this.localBabyId,
    this.aiHistory = '',
  });

  OnboardingDraft copyWith({
    String? stage,
    int? step,
    String? babyName,
    DateTime? birthDate,
    bool clearBirthDate = false,
    double? weightKg,
    bool clearWeightKg = false,
    double? heightCm,
    bool clearHeightCm = false,
    String? motherName,
    DateTime? motherBirthDate,
    bool clearMotherBirthDate = false,
    String? fatherName,
    DateTime? fatherBirthDate,
    bool clearFatherBirthDate = false,
    double? motherHeightCm,
    bool clearMotherHeightCm = false,
    double? fatherHeightCm,
    bool clearFatherHeightCm = false,
    String? babyPhotoB64,
    bool clearBabyPhotoB64 = false,
    String? motherPhotoB64,
    bool clearMotherPhotoB64 = false,
    String? fatherPhotoB64,
    bool clearFatherPhotoB64 = false,
    bool? registerFather,
    bool clearRegisterFather = false,
    String? sex,
    bool? firstBaby,
    bool clearFirstBaby = false,
    List<String>? concerns,
    List<String>? goals,
    List<String>? familyMessageKinds,
    String? familyMessageChoice,
    bool clearFamilyMessageChoice = false,
    int? localMotherId,
    int? localBabyId,
    String? aiHistory,
  }) {
    return OnboardingDraft(
      stage: stage ?? this.stage,
      step: step ?? this.step,
      babyName: babyName ?? this.babyName,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      weightKg: clearWeightKg ? null : (weightKg ?? this.weightKg),
      heightCm: clearHeightCm ? null : (heightCm ?? this.heightCm),
      motherName: motherName ?? this.motherName,
      motherBirthDate: clearMotherBirthDate
          ? null
          : (motherBirthDate ?? this.motherBirthDate),
      fatherName: fatherName ?? this.fatherName,
      fatherBirthDate: clearFatherBirthDate
          ? null
          : (fatherBirthDate ?? this.fatherBirthDate),
      motherHeightCm:
          clearMotherHeightCm ? null : (motherHeightCm ?? this.motherHeightCm),
      fatherHeightCm:
          clearFatherHeightCm ? null : (fatherHeightCm ?? this.fatherHeightCm),
      babyPhotoB64:
          clearBabyPhotoB64 ? null : (babyPhotoB64 ?? this.babyPhotoB64),
      motherPhotoB64:
          clearMotherPhotoB64 ? null : (motherPhotoB64 ?? this.motherPhotoB64),
      fatherPhotoB64: clearFatherPhotoB64
          ? null
          : (fatherPhotoB64 ?? this.fatherPhotoB64),
      registerFather:
          clearRegisterFather ? null : (registerFather ?? this.registerFather),
      sex: sex ?? this.sex,
      firstBaby: clearFirstBaby ? null : (firstBaby ?? this.firstBaby),
      concerns: concerns ?? this.concerns,
      goals: goals ?? this.goals,
      familyMessageKinds: familyMessageKinds ?? this.familyMessageKinds,
      familyMessageChoice: clearFamilyMessageChoice
          ? null
          : (familyMessageChoice ?? this.familyMessageChoice),
      localMotherId: localMotherId ?? this.localMotherId,
      localBabyId: localBabyId ?? this.localBabyId,
      aiHistory: aiHistory ?? this.aiHistory,
    );
  }

  Map<String, Object?> toJson() => {
        'stage': stage,
        'step': step,
        'babyName': babyName,
        'birthDate': birthDate?.toIso8601String(),
        'weightKg': weightKg,
        'heightCm': heightCm,
        'motherName': motherName,
        'motherBirthDate': motherBirthDate?.toIso8601String(),
        'fatherName': fatherName,
        'fatherBirthDate': fatherBirthDate?.toIso8601String(),
        'motherHeightCm': motherHeightCm,
        'fatherHeightCm': fatherHeightCm,
        'babyPhotoB64': babyPhotoB64,
        'motherPhotoB64': motherPhotoB64,
        'fatherPhotoB64': fatherPhotoB64,
        'registerFather': registerFather,
        'sex': sex,
        'firstBaby': firstBaby,
        'concerns': concerns,
        'goals': goals,
        'familyMessageKinds': familyMessageKinds,
        'familyMessageChoice': familyMessageChoice,
        'localMotherId': localMotherId,
        'localBabyId': localBabyId,
        'aiHistory': aiHistory,
        'draftFormat': 2,
      };

  /// Migra índice de passo (fluxo com 17 passos → 19 com fotos mãe e bebê).
  static int _migrateStepV1ToV2(int oldStep) {
    if (oldStep < 5) return oldStep;
    var s = oldStep + 1;
    if (s >= 10) s += 1;
    return s.clamp(0, 19);
  }

  static OnboardingDraft fromJson(Map<String, Object?> json) {
    List<String> stringList(Object? value) {
      if (value is List) return value.map((e) => '$e').toList(growable: false);
      return const [];
    }

    final draftFormat = (json['draftFormat'] as num?)?.toInt() ?? 1;
    var step = (json['step'] as num?)?.toInt() ?? 0;
    final stage = (json['stage'] as String?) ?? 'welcome';
    if (draftFormat < 2 && stage == 'questions') {
      step = _migrateStepV1ToV2(step);
    }

    return OnboardingDraft(
      stage: stage,
      step: step,
      babyName: (json['babyName'] as String?) ?? '',
      birthDate: DateTime.tryParse((json['birthDate'] as String?) ?? ''),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      motherName: (json['motherName'] as String?) ?? '',
      motherBirthDate:
          DateTime.tryParse((json['motherBirthDate'] as String?) ?? ''),
      fatherName: (json['fatherName'] as String?) ?? '',
      fatherBirthDate:
          DateTime.tryParse((json['fatherBirthDate'] as String?) ?? ''),
      motherHeightCm: (json['motherHeightCm'] as num?)?.toDouble(),
      fatherHeightCm: (json['fatherHeightCm'] as num?)?.toDouble(),
      babyPhotoB64: (json['babyPhotoB64'] as String?)?.trim(),
      motherPhotoB64: (json['motherPhotoB64'] as String?)?.trim(),
      fatherPhotoB64: (json['fatherPhotoB64'] as String?)?.trim(),
      registerFather: json['registerFather'] as bool?,
      sex: (json['sex'] as String?) ?? '',
      firstBaby: json['firstBaby'] as bool?,
      concerns: stringList(json['concerns']),
      goals: stringList(json['goals']),
      familyMessageKinds: _parseFamilyMessageKinds(json),
      familyMessageChoice: (json['familyMessageChoice'] as String?)?.trim(),
      localMotherId: (json['localMotherId'] as num?)?.toInt(),
      localBabyId: (json['localBabyId'] as num?)?.toInt(),
      aiHistory: (json['aiHistory'] as String?) ?? '',
    );
  }
}

List<String> _parseFamilyMessageKinds(Map<String, Object?> json) {
  final raw = json['familyMessageKinds'];
  if (raw is List && raw.isNotEmpty) {
    return raw.map((e) => '$e'.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
  }
  final legacy = (json['familyMessageChoice'] as String?)?.trim();
  if (legacy == null || legacy.isEmpty) return const [];
  return switch (legacy.toLowerCase()) {
    'christian' => const ['christian'],
    'horoscope' => const ['horoscope'],
    'both' => const ['christian', 'horoscope'],
    'all' => const ['christian', 'horoscope', 'spiritist', 'jewish'],
    'none' => const [],
    _ => const ['horoscope'],
  };
}

abstract final class OnboardingDraftStore {
  OnboardingDraftStore._();

  static const _key = 'facebaby_onboarding_draft_v1';

  static Future<OnboardingDraft> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return const OnboardingDraft();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return OnboardingDraft.fromJson(decoded);
      }
      if (decoded is Map) {
        return OnboardingDraft.fromJson(Map<String, Object?>.from(decoded));
      }
    } catch (_) {}
    return const OnboardingDraft();
  }

  static Future<void> save(OnboardingDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(draft.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
