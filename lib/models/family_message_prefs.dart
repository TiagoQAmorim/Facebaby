/// Preferências de mensagens na tela Família (cristã / horóscopo).
class FamilyMessagePrefs {
  final bool showChristian;
  final bool showHoroscope;

  const FamilyMessagePrefs({
    required this.showChristian,
    required this.showHoroscope,
  });

  static const horoscopeOnly =
      FamilyMessagePrefs(showChristian: false, showHoroscope: true);

  static const christianOnly =
      FamilyMessagePrefs(showChristian: true, showHoroscope: false);

  static const both =
      FamilyMessagePrefs(showChristian: true, showHoroscope: true);

  static FamilyMessagePrefs fromMother(Map<String, Object?>? mother) {
    if (mother == null) return horoscopeOnly;
    final c = mother['show_family_christian'];
    final h = mother['show_family_horoscope'];
    final christian = c == true || c == 1;
    final horoscope = h == null ? true : (h == true || h == 1);
    return FamilyMessagePrefs(
      showChristian: christian,
      showHoroscope: horoscope,
    );
  }

  static FamilyMessagePrefs fromOnboardingChoice(String? choice) {
    return switch (choice) {
      'christian' => christianOnly,
      'both' => both,
      _ => horoscopeOnly,
    };
  }
}
