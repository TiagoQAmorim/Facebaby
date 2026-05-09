import '../models/baby.dart';
import '../models/daily_summary.dart';
import '../models/home_day_snapshot.dart';
import '../models/memory_item.dart';

class MockBabyService {
  Baby getBaby() => const Baby(
        name: 'Maitê',
        ageLabel: '9 semanas',
        avatar: '👶',
        weightKg: 5.45,
        heightCm: 58,
        birthDate: null,
      );

  DailySummary getDailySummary() => const DailySummary(
        feedings: 5,
        feedingMinutesTotal: 48,
        sleep: '3h 20m',
        sleepSessions: 4,
        diapers: 6,
        diaperPee: 4,
        diaperPoo: 3,
        weight: '5,450 kg',
        sleepTotalSeconds: 12000,
      );

  /// Deterministic demo data per calendar day (past days on Home).
  HomeDaySnapshot snapshotForDay(DateTime calendarDay) {
    final base = DateTime(calendarDay.year, calendarDay.month, calendarDay.day);
    final seed = base.year * 502 + base.month * 32 + base.day;

    final feedings = 3 + (seed % 5);
    final feedingMin = feedings * 10 + (seed % 25);
    final sleepH = 2 + (seed % 5);
    final sleepM = (seed * 13) % 50;
    final diapers = 4 + (seed % 8);
    final diaperPee = diapers - (seed % 3);
    final diaperPoo = seed % 4;
    final sleepSessions = 2 + (seed % 5);
    final sleepTotalSec = sleepH * 3600 + sleepM * 60;
    final wMilli = 5200 + (seed % 120);
    final wStr = (wMilli / 1000).toStringAsFixed(3).replaceAll('.', ',');
    final weight = '$wStr kg';

    final lastFeed = base.add(Duration(hours: 6 + seed % 12, minutes: (seed * 3) % 56));
    final lastSleep = base.add(Duration(hours: 20 + seed % 3, minutes: (seed * 5) % 50));
    final lastPee = base.add(Duration(hours: 1 + seed % 7, minutes: (seed * 7) % 58));
    final lastPoo = base.add(Duration(hours: 8 + seed % 9, minutes: (seed * 11) % 58));

    return HomeDaySnapshot(
      summary: DailySummary(
        feedings: feedings,
        feedingMinutesTotal: feedingMin,
        sleep: '${sleepH}h ${sleepM.toString().padLeft(2, '0')}m',
        sleepSessions: sleepSessions,
        diapers: diapers,
        diaperPee: diaperPee.clamp(0, diapers),
        diaperPoo: diaperPoo,
        weight: weight,
        sleepTotalSeconds: sleepTotalSec,
      ),
      lastFeedingAt: lastFeed,
      lastSleepAt: lastSleep,
      lastPeeAt: lastPee,
      lastPooAt: lastPoo,
    );
  }

  List<MemoryItem> getMemories() => const [
        MemoryItem(
          title: 'Primeiro sorriso',
          date: '20/04/2026',
          description: 'Um sorriso lindo depois da amamentação da manhã.',
          emoji: '😊',
        ),
        MemoryItem(
          title: 'Primeira consulta',
          date: '14/04/2026',
          description: 'Consulta com pediatra e acompanhamento do peso.',
          emoji: '🩺',
        ),
        MemoryItem(
          title: 'Momento com a mamãe',
          date: '10/04/2026',
          description: 'Registro especial para entrar no livro de recordações.',
          emoji: '💜',
        ),
      ];

  /// Same three highlights as [getMemories], in English (for non-PT locales defaulting to EN content).
  List<MemoryItem> getMemoriesEn() => const [
        MemoryItem(
          title: 'First smile',
          date: '20/04/2026',
          description: 'A beautiful smile after the morning feeding.',
          emoji: '😊',
        ),
        MemoryItem(
          title: 'First check-up',
          date: '14/04/2026',
          description: 'Pediatric visit and weight follow-up.',
          emoji: '🩺',
        ),
        MemoryItem(
          title: 'A moment with mom',
          date: '10/04/2026',
          description: 'A special entry for the memory book.',
          emoji: '💜',
        ),
      ];
}
