import 'package:facebaby_flutter/models/family_message_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('showPhilosophical reflects spiritist or jewish', () {
    const none = FamilyMessagePrefs(
      showChristian: false,
      showHoroscope: false,
      showSpiritist: false,
      showJewish: false,
    );
    expect(none.showPhilosophical, isFalse);

    const spiritist = FamilyMessagePrefs(
      showChristian: false,
      showHoroscope: false,
      showSpiritist: true,
      showJewish: false,
    );
    expect(spiritist.showPhilosophical, isTrue);

    const jewish = FamilyMessagePrefs(
      showChristian: false,
      showHoroscope: false,
      showSpiritist: false,
      showJewish: true,
    );
    expect(jewish.showPhilosophical, isTrue);
  });

  test('withPhilosophical toggles both spiritist and jewish', () {
    const base = FamilyMessagePrefs(
      showChristian: true,
      showHoroscope: true,
      showSpiritist: false,
      showJewish: false,
    );
    final on = base.withPhilosophical(true);
    expect(on.showSpiritist, isTrue);
    expect(on.showJewish, isTrue);
    expect(on.showPhilosophical, isTrue);

    final off = on.withPhilosophical(false);
    expect(off.showSpiritist, isFalse);
    expect(off.showJewish, isFalse);
    expect(off.showPhilosophical, isFalse);
  });
}
