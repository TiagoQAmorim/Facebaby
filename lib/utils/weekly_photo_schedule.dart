/// Regras da “Foto da Semana” (Príncipe/Princesa da semana):
/// - Candidaturas: segunda a domingo da semana ISO (marcação pública até passar a meia-noite
///   de domingo → exclusivo segunda seguinte 00:00).
/// - Sorteio na nuvem: domingo ~23:58 (America/Sao_Paulo), com base nas memórias da **semana
///   ISO que acaba** nesse domingo (`submissionWeekId` = segunda dessa semana).
/// - Exibição na Home: segunda 00:00 à segunda seguinte 00:00 (todos os utilizadores autenticados
///   veem o mesmo `spotlight_current`).
class WeeklyPhotoSchedule {
  WeeklyPhotoSchedule._();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Segunda-feira 00:00 da semana ISO que contém [d].
  static DateTime mondayOfIsoWeekContaining(DateTime d) {
    final day = _dateOnly(d);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// Segunda 00:00 **depois** da semana ISO de [anyInWeek] (início da semana seguinte).
  static DateTime mondayAfterIsoWeekContaining(DateTime anyInWeek) {
    final mon = mondayOfIsoWeekContaining(anyInWeek);
    return mon.add(const Duration(days: 7));
  }

  /// Janela de candidatura: qualquer momento dentro da semana ISO (seg 00:00 ≤ t < seg seguinte).
  /// Equivale a “até 00h de domingo” no sentido de incluir todo o domingo até virar segunda.
  static bool isInCollectionWindow(DateTime t) {
    final mon = mondayOfIsoWeekContaining(t);
    final nextMon = mon.add(const Duration(days: 7));
    return !t.isBefore(mon) && t.isBefore(nextMon);
  }

  /// Identificador estável da semana do concurso: `YYYY-MM-DD` da segunda ISO da semana em que
  /// a memória ficou pública (e entra no pool desse sorteio).
  static String contestWeekId(DateTime anyMomentInWeek) {
    final mon = mondayOfIsoWeekContaining(anyMomentInWeek);
    return '${mon.year.toString().padLeft(4, '0')}-'
        '${mon.month.toString().padLeft(2, '0')}-'
        '${mon.day.toString().padLeft(2, '0')}';
  }

  /// A marcação pública conta para o sorteio dessa semana ISO (seg–dom).
  static bool isMarkEligibleForWeeklyDraw(DateTime markPublicAt) {
    return isInCollectionWindow(markPublicAt);
  }

  /// Badge “Participando da Foto da Semana”: opt-in na semana do pool e até à segunda em que
  /// o destaque desse sorteio entra em vigor (a segunda **após** o fim da semana ISO da marcação).
  static bool showParticipatingBadge({
    required bool isPublic,
    required bool hasPhoto,
    required DateTime? publicEnabledAt,
    required DateTime now,
  }) {
    if (!isPublic || !hasPhoto || publicEnabledAt == null) return false;
    if (!isInCollectionWindow(publicEnabledAt)) return false;
    if (contestWeekId(publicEnabledAt) != contestWeekId(now)) return false;
    final spotlightStarts = mondayAfterIsoWeekContaining(publicEnabledAt);
    return now.isBefore(spotlightStarts);
  }

  /// Spotlight visível entre [drawAt] (segunda 00:00 do período de exibição) e [displayUntil]
  /// (segunda seguinte 00:00), conforme gravado em `spotlight_current`.
  static bool isWithinSpotlightDisplay({
    required DateTime now,
    required DateTime drawAt,
    required DateTime displayUntil,
  }) {
    return !now.isBefore(drawAt) && now.isBefore(displayUntil);
  }
}
