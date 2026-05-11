/// Regras da “Foto da Semana”: coleta segunda–quinta, sorteio sexta,
/// exibição sexta 00:00 até segunda 00:00 (horário local do dispositivo).
class WeeklyPhotoSchedule {
  WeeklyPhotoSchedule._();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Segunda-feira 00:00 da semana ISO que contém [d].
  static DateTime mondayOfIsoWeekContaining(DateTime d) {
    final day = _dateOnly(d);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// true se [t] (data/hora local) está entre segunda 00:00 e quinta 23:59:59.
  static bool isInCollectionWindow(DateTime t) {
    final wd = t.weekday;
    if (wd < DateTime.monday || wd > DateTime.thursday) return false;
    return true;
  }

  /// Identificador estável da semana do sorteio (sexta que encerra o ciclo): `YYYY-MM-DD` da segunda ISO.
  static String contestWeekId(DateTime anyMomentInWeek) {
    final mon = mondayOfIsoWeekContaining(anyMomentInWeek);
    return '${mon.year.toString().padLeft(4, '0')}-'
        '${mon.month.toString().padLeft(2, '0')}-'
        '${mon.day.toString().padLeft(2, '0')}';
  }

  /// Quando a mãe marca público durante seg–qui, a marca entra no sorteio da **sexta seguinte**
  /// (ainda na mesma semana ISO da marca).
  static bool isMarkEligibleForWeeklyDraw(DateTime markPublicAt) {
    return isInCollectionWindow(markPublicAt);
  }

  /// Badge “Participando da Foto da Semana”: opt-in na janela desta semana e antes do sorteio (sexta 00:00).
  static bool showParticipatingBadge({
    required bool isPublic,
    required bool hasPhoto,
    required DateTime? publicEnabledAt,
    required DateTime now,
  }) {
    if (!isPublic || !hasPhoto || publicEnabledAt == null) return false;
    if (!isInCollectionWindow(publicEnabledAt)) return false;
    if (contestWeekId(publicEnabledAt) != contestWeekId(now)) return false;
    final draw = fridayDrawAt(publicEnabledAt);
    return now.isBefore(draw);
  }

  /// Sexta-feira 00:00 da semana ISO que contém [anyInWeek] (referência para sorteio).
  static DateTime fridayDrawAt(DateTime anyInWeek) {
    final mon = mondayOfIsoWeekContaining(anyInWeek);
    return mon.add(const Duration(days: 4)); // seg + 4 = sex
  }

  /// Segunda 00:00 após o período de exibição (fim do spotlight na Home).
  static DateTime displayEndMondayAfterFriday(DateTime fridayDraw) {
    final monAfter = mondayOfIsoWeekContaining(fridayDraw).add(const Duration(days: 7));
    return monAfter;
  }

  /// Spotlight visível entre [drawAt] (sexta 00:00) e [displayUntil] (segunda 00:00 seguinte).
  static bool isWithinSpotlightDisplay({
    required DateTime now,
    required DateTime drawAt,
    required DateTime displayUntil,
  }) {
    return !now.isBefore(drawAt) && now.isBefore(displayUntil);
  }
}
