import 'dart:convert';

import 'package:flutter/services.dart';

import '../i18n/app_i18n.dart';

/// Frases inspiracionais (espíritas / judaicas) por idioma — uma frase por entrada.
class FamilyPhraseContentService {
  FamilyPhraseContentService._(this._assetPath);

  static final FamilyPhraseContentService spiritist = FamilyPhraseContentService._(
    'assets/data/family_spiritist_content.json',
  );

  static final FamilyPhraseContentService jewish = FamilyPhraseContentService._(
    'assets/data/family_jewish_content.json',
  );

  final String _assetPath;
  Map<String, List<String>>? _byLang;

  Future<void> ensureLoaded() async {
    if (_byLang != null) return;
    final raw = await rootBundle.loadString(_assetPath);
    final root = jsonDecode(raw) as Map<String, dynamic>;
    final parsed = <String, List<String>>{};
    for (final e in root.entries) {
      final list = e.value;
      if (list is! List) continue;
      parsed[e.key] = [
        for (final item in list)
          if (item != null) '$item'.trim(),
      ].where((t) => t.isNotEmpty).toList(growable: false);
    }
    _byLang = parsed;
  }

  String _langKey(AppLang lang) => switch (lang) {
        AppLang.pt => 'pt',
        AppLang.en => 'en',
        AppLang.es => 'es',
        AppLang.fr => 'fr',
        AppLang.de => 'de',
        AppLang.it => 'it',
        _ => 'en',
      };

  List<String> phrases(AppLang lang) {
    final list = _byLang?[_langKey(lang)] ?? _byLang?['en'];
    return list ?? const [];
  }

  static int _daySalt(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return d.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  static int _index({
    required int count,
    required int daySalt,
    required int roleSalt,
    required int memberSalt,
  }) {
    if (count <= 0) return 0;
    final mix = daySalt * 10007 + roleSalt * 7919 + memberSalt * 9973;
    return mix.abs() % count;
  }

  /// Frase do dia (estável por dia + membro).
  String? phraseFor(
    AppLang lang, {
    required int roleSalt,
    int memberSalt = 0,
    DateTime? calendarDay,
  }) {
    final all = phrases(lang);
    if (all.isEmpty) return null;
    final day = calendarDay ?? DateTime.now();
    final index = _index(
      count: all.length,
      daySalt: _daySalt(day),
      roleSalt: roleSalt,
      memberSalt: memberSalt,
    );
    return all[index];
  }
}
