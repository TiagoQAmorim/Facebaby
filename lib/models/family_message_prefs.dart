import 'family_message_kind.dart';

/// Preferências de mensagens na tela Família.
class FamilyMessagePrefs {
  final bool showChristian;
  final bool showHoroscope;
  final bool showSpiritist;
  final bool showJewish;

  const FamilyMessagePrefs({
    required this.showChristian,
    required this.showHoroscope,
    required this.showSpiritist,
    required this.showJewish,
  });

  bool get hasAny =>
      showChristian || showHoroscope || showSpiritist || showJewish;

  static const horoscopeOnly = FamilyMessagePrefs(
    showChristian: false,
    showHoroscope: true,
    showSpiritist: false,
    showJewish: false,
  );

  static const all = FamilyMessagePrefs(
    showChristian: true,
    showHoroscope: true,
    showSpiritist: true,
    showJewish: true,
  );

  static const none = FamilyMessagePrefs(
    showChristian: false,
    showHoroscope: false,
    showSpiritist: false,
    showJewish: false,
  );

  static FamilyMessagePrefs fromMother(Map<String, Object?>? mother) {
    if (mother == null) return horoscopeOnly;
    bool readBool(Object? v, {required bool defaultValue}) {
      if (v == null) return defaultValue;
      if (v is bool) return v;
      if (v is num) return v.toInt() == 1;
      return defaultValue;
    }

    return FamilyMessagePrefs(
      showChristian: readBool(mother['show_family_christian'], defaultValue: false),
      showHoroscope: readBool(mother['show_family_horoscope'], defaultValue: true),
      showSpiritist: readBool(mother['show_family_spiritist'], defaultValue: false),
      showJewish: readBool(mother['show_family_jewish'], defaultValue: false),
    );
  }

  static FamilyMessagePrefs fromKinds(Iterable<String> kinds) {
    final set = kinds.map((e) => e.trim().toLowerCase()).toSet();
    return FamilyMessagePrefs(
      showChristian: set.contains(FamilyMessageKind.christian),
      showHoroscope: set.contains(FamilyMessageKind.horoscope),
      showSpiritist: set.contains(FamilyMessageKind.spiritist),
      showJewish: set.contains(FamilyMessageKind.jewish),
    );
  }

  /// Compatível com rascunhos antigos do onboarding (`christian` | `horoscope` | `both` | `none`).
  static FamilyMessagePrefs fromOnboardingChoice(String? choice) {
    return switch (choice?.trim().toLowerCase()) {
      'christian' => const FamilyMessagePrefs(
          showChristian: true,
          showHoroscope: false,
          showSpiritist: false,
          showJewish: false,
        ),
      'both' => const FamilyMessagePrefs(
          showChristian: true,
          showHoroscope: true,
          showSpiritist: false,
          showJewish: false,
        ),
      'all' => all,
      'none' => none,
      _ => horoscopeOnly,
    };
  }

  List<String> toKinds() {
    final out = <String>[];
    if (showChristian) out.add(FamilyMessageKind.christian);
    if (showHoroscope) out.add(FamilyMessageKind.horoscope);
    if (showSpiritist) out.add(FamilyMessageKind.spiritist);
    if (showJewish) out.add(FamilyMessageKind.jewish);
    return out;
  }
}
