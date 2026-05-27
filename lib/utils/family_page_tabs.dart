import '../models/family_message_prefs.dart';

/// Índices das guias superiores em [FamilyTreePage] (Família → opcionais → Histórico IA).
abstract final class FamilyPageTabs {
  FamilyPageTabs._();

  static const int tree = 0;

  static int tabCount(FamilyMessagePrefs prefs) {
    var n = 2;
    if (prefs.showChristian) n++;
    if (prefs.showHoroscope) n++;
    return n;
  }

  static int? homily(FamilyMessagePrefs prefs) =>
      prefs.showChristian ? 1 : null;

  static int? horoscope(FamilyMessagePrefs prefs) {
    if (!prefs.showHoroscope) return null;
    var idx = 1;
    if (prefs.showChristian) idx++;
    return idx;
  }

  static int history(FamilyMessagePrefs prefs) {
    var idx = 1;
    if (prefs.showChristian) idx++;
    if (prefs.showHoroscope) idx++;
    return idx;
  }
}
