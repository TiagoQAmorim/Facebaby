import 'package:flutter/foundation.dart';

/// Faixa etária (meses) e janela recomendada entre sonos (minutos acordado).
@immutable
class SleepWindowRow {
  final int ageMinMonthsExclusive;
  final int ageMaxMonthsInclusive;
  final int minAwakeMin;
  final int maxAwakeMin;

  const SleepWindowRow({
    required this.ageMinMonthsExclusive,
    required this.ageMaxMonthsInclusive,
    required this.minAwakeMin,
    required this.maxAwakeMin,
  });
}

/// Tabela integrada (equivalente ao documento de produto).
///
/// **Minutos acordado entre sonos** (não é duração do sono). Não há ecrã de definições — só esta lista.
/// Meses completos (`monthsOld`): **0–3** → 45–90 | **4–6** → 90–150 | **7–9** → 120–180 |
/// **10–12** → 150–210 | **13–18** → 180–240 | **19–24** → 240–360 | **25–36** → 300–420.
const List<SleepWindowRow> kSleepWindowsByAge = [
  SleepWindowRow(ageMinMonthsExclusive: -1, ageMaxMonthsInclusive: 3, minAwakeMin: 45, maxAwakeMin: 90),
  SleepWindowRow(ageMinMonthsExclusive: 3, ageMaxMonthsInclusive: 6, minAwakeMin: 90, maxAwakeMin: 150),
  SleepWindowRow(ageMinMonthsExclusive: 6, ageMaxMonthsInclusive: 9, minAwakeMin: 120, maxAwakeMin: 180),
  SleepWindowRow(ageMinMonthsExclusive: 9, ageMaxMonthsInclusive: 12, minAwakeMin: 150, maxAwakeMin: 210),
  SleepWindowRow(ageMinMonthsExclusive: 12, ageMaxMonthsInclusive: 18, minAwakeMin: 180, maxAwakeMin: 240),
  SleepWindowRow(ageMinMonthsExclusive: 18, ageMaxMonthsInclusive: 24, minAwakeMin: 240, maxAwakeMin: 360),
  SleepWindowRow(ageMinMonthsExclusive: 24, ageMaxMonthsInclusive: 36, minAwakeMin: 300, maxAwakeMin: 420),
];

enum SleepRoutinePhase {
  /// timeAwake &lt; min
  early,

  /// min &lt;= timeAwake &lt;= max
  idealWindow,

  /// timeAwake &gt; max
  overdue,
}

abstract final class SleepRoutine {
  SleepRoutine._();

  /// Idade em meses completos (aproximação por calendário).
  static int monthsOld(DateTime? birthDate) {
    if (birthDate == null) return 3;
    final now = DateTime.now();
    var m = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
    if (now.day < birthDate.day) m--;
    return m.clamp(0, 48);
  }

  static SleepWindowRow windowForMonths(int months) {
    for (final row in kSleepWindowsByAge) {
      if (months > row.ageMinMonthsExclusive && months <= row.ageMaxMonthsInclusive) {
        return row;
      }
    }
    return kSleepWindowsByAge.last;
  }

  static SleepRoutinePhase phaseFor({required int awakeMinutes, required SleepWindowRow w}) {
    final minW = w.minAwakeMin;
    final maxW = w.maxAwakeMin;
    if (awakeMinutes < minW) return SleepRoutinePhase.early;
    if (awakeMinutes <= maxW) return SleepRoutinePhase.idealWindow;
    return SleepRoutinePhase.overdue;
  }

  /// Posição 0–1 na barra com três zonas iguais (verde | amarelo | vermelho).
  /// [awakeMinutes] pode ser fracionário (segundos/60) para a barra evoluir entre minutos inteiros.
  static double markerThreeZones({
    required double awakeMinutes,
    required SleepWindowRow w,
  }) {
    final minW = w.minAwakeMin.toDouble();
    final maxW = w.maxAwakeMin.toDouble();
    if (maxW <= minW) return 0.5;

    if (awakeMinutes < minW) {
      final t = awakeMinutes / minW;
      return (t * (1 / 3)).clamp(0.0, 1 / 3);
    }
    if (awakeMinutes <= maxW) {
      final span = maxW - minW;
      final frac = span > 0 ? (awakeMinutes - minW) / span : 0.5;
      return (1 / 3 + frac * (1 / 3)).clamp(1 / 3, 2 / 3);
    }
    final over = awakeMinutes - maxW;
    final redSpan = maxW.clamp(30, 180).toDouble();
    final frac = (over / redSpan).clamp(0.0, 1.0);
    return (2 / 3 + frac * (1 / 3)).clamp(2 / 3, 1.0);
  }

  /// Minutos até o próximo “marco” para o cabeçalho (estimativa simples).
  static int estimateNextNapMinutes({
    required int awakeMinutes,
    required SleepWindowRow w,
  }) {
    final minW = w.minAwakeMin;
    final maxW = w.maxAwakeMin;
    if (awakeMinutes < minW) return (minW - awakeMinutes).clamp(1, 999);
    if (awakeMinutes <= maxW) return (maxW - awakeMinutes).clamp(0, 999);
    return 0;
  }
}
