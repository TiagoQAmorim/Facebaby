import 'daily_summary.dart';

/// Mock snapshot of home metrics for a calendar day (used for past days on Home).
class HomeDaySnapshot {
  final DailySummary summary;
  final DateTime lastFeedingAt;
  final DateTime lastSleepAt;
  final DateTime lastPeeAt;
  final DateTime lastPooAt;

  const HomeDaySnapshot({
    required this.summary,
    required this.lastFeedingAt,
    required this.lastSleepAt,
    required this.lastPeeAt,
    required this.lastPooAt,
  });
}
