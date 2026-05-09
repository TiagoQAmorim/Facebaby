import 'package:flutter/foundation.dart';

@immutable
class FeedingWindowRow {
  final int ageMinMonthsExclusive;
  final int ageMaxMonthsInclusive;
  final int intervalMinutes;

  const FeedingWindowRow({
    required this.ageMinMonthsExclusive,
    required this.ageMaxMonthsInclusive,
    required this.intervalMinutes,
  });
}

/// Defaults por idade (tabela de produto).
const List<FeedingWindowRow> kFeedingIntervalsByAge = [
  FeedingWindowRow(ageMinMonthsExclusive: -1, ageMaxMonthsInclusive: 3, intervalMinutes: 120),
  FeedingWindowRow(ageMinMonthsExclusive: 3, ageMaxMonthsInclusive: 6, intervalMinutes: 150),
  FeedingWindowRow(ageMinMonthsExclusive: 6, ageMaxMonthsInclusive: 9, intervalMinutes: 180),
  FeedingWindowRow(ageMinMonthsExclusive: 9, ageMaxMonthsInclusive: 12, intervalMinutes: 210),
  FeedingWindowRow(ageMinMonthsExclusive: 12, ageMaxMonthsInclusive: 18, intervalMinutes: 240),
  FeedingWindowRow(ageMinMonthsExclusive: 18, ageMaxMonthsInclusive: 24, intervalMinutes: 300),
  FeedingWindowRow(ageMinMonthsExclusive: 24, ageMaxMonthsInclusive: 36, intervalMinutes: 360),
];

abstract final class FeedingRoutine {
  FeedingRoutine._();

  static int monthsOld(DateTime? birthDate) {
    if (birthDate == null) return 3;
    final now = DateTime.now();
    var m = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
    if (now.day < birthDate.day) m--;
    return m.clamp(0, 48);
  }

  static int recommendedIntervalMinutes(int months) {
    for (final row in kFeedingIntervalsByAge) {
      if (months > row.ageMinMonthsExclusive && months <= row.ageMaxMonthsInclusive) {
        return row.intervalMinutes;
      }
    }
    return kFeedingIntervalsByAge.last.intervalMinutes;
  }
}

