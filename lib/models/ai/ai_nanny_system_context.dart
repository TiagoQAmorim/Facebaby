/// Sessão de sono ativa (cronômetro do app).
class ActiveSleepSessionInfo {
  const ActiveSleepSessionInfo({
    required this.babyId,
    required this.startedAt,
    required this.durationMinutes,
    required this.durationSec,
    this.isPaused = false,
  });

  final int babyId;
  final DateTime startedAt;
  final int durationMinutes;
  final int durationSec;
  final bool isPaused;

  String get durationLabel {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h > 0 && m > 0) return '${h}h${m.toString().padLeft(2, '0')}';
    if (h > 0) return '${h}h';
    return '${m}min';
  }

  String startedAtClockLabel() {
    final h = startedAt.hour.toString().padLeft(2, '0');
    final m = startedAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toMap() => {
        'babyId': babyId,
        'startedAt': startedAt.toIso8601String(),
        'durationMinutes': durationMinutes,
        'durationSec': durationSec,
        'isPaused': isPaused,
      };
}

/// Sessão de amamentação ativa (cronômetro E/D).
class ActiveBreastfeedingSessionInfo {
  const ActiveBreastfeedingSessionInfo({
    required this.babyId,
    required this.side,
    required this.startedAt,
    required this.durationMinutes,
  });

  final int babyId;
  final String side;
  final DateTime startedAt;
  final int durationMinutes;

  String get durationLabel {
    final m = durationMinutes;
    if (m >= 60) {
      final h = m ~/ 60;
      final r = m % 60;
      if (r > 0) return '${h}h${r.toString().padLeft(2, '0')}';
      return '${h}h';
    }
    return '${m}min';
  }

  Map<String, dynamic> toMap() => {
        'babyId': babyId,
        'side': side,
        'startedAt': startedAt.toIso8601String(),
        'durationMinutes': durationMinutes,
      };
}

/// Estado real do app consultado antes de interpretar/registrar.
class AiNannySystemContext {
  const AiNannySystemContext({
    this.babyId,
    this.activeSleep,
    this.activeBreastfeeding,
    this.hasPendingRecordSession = false,
  });

  final int? babyId;
  final ActiveSleepSessionInfo? activeSleep;
  final ActiveBreastfeedingSessionInfo? activeBreastfeeding;
  final bool hasPendingRecordSession;

  bool get hasActiveSleepForBaby =>
      babyId != null &&
      activeSleep != null &&
      activeSleep!.babyId == babyId;

  bool get hasActiveBreastfeedingForBaby =>
      babyId != null &&
      activeBreastfeeding != null &&
      activeBreastfeeding!.babyId == babyId;

  Map<String, dynamic> toMap() => {
        if (babyId != null) 'babyId': babyId,
        if (activeSleep != null) 'activeSleepSession': activeSleep!.toMap(),
        if (activeBreastfeeding != null)
          'activeBreastfeedingSession': activeBreastfeeding!.toMap(),
        'hasPendingRecordSession': hasPendingRecordSession,
      };
}
