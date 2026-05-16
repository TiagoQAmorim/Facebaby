import 'dart:convert';

import 'package:flutter/services.dart';

import '../i18n/app_i18n.dart';

enum FamilyChristianRole { mother, father, baby }

class FamilyChristianVerse {
  final String text;
  final String reference;

  const FamilyChristianVerse({required this.text, required this.reference});
}

/// Passagens bíblicas sobre família por idioma.
class FamilyChristianContentService {
  FamilyChristianContentService._();
  static final FamilyChristianContentService instance =
      FamilyChristianContentService._();

  static const _assetPath = 'assets/data/family_christian_content.json';

  Map<String, List<FamilyChristianVerse>>? _byLang;

  Future<void> ensureLoaded() async {
    if (_byLang != null) return;
    final raw = await rootBundle.loadString(_assetPath);
    final root = jsonDecode(raw) as Map<String, dynamic>;
    final parsed = <String, List<FamilyChristianVerse>>{};
    for (final e in root.entries) {
      final list = e.value;
      if (list is! List) continue;
      parsed[e.key] = [
        for (final item in list)
          if (item is Map)
            FamilyChristianVerse(
              text: '${item['text'] ?? ''}'.trim(),
              reference: '${item['reference'] ?? ''}'.trim(),
            ),
      ].where((v) => v.text.isNotEmpty).toList(growable: false);
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

  List<FamilyChristianVerse> verses(AppLang lang) {
    final list = _byLang?[_langKey(lang)] ?? _byLang?['en'];
    return list ?? const [];
  }

  FamilyChristianVerse? verseFor(
    AppLang lang,
    FamilyChristianRole role, {
    int? babyId,
  }) {
    final all = verses(lang);
    if (all.isEmpty) return null;
    final seed = switch (role) {
      FamilyChristianRole.mother => 0,
      FamilyChristianRole.father => 11,
      FamilyChristianRole.baby => 17 + (babyId ?? 0),
    };
    return all[seed % all.length];
  }

  String body(AppLang lang, FamilyChristianRole role, {int? babyId}) {
    final v = verseFor(lang, role, babyId: babyId);
    if (v == null) return '';
    return '${v.text}\n\n— ${v.reference}';
  }
}
