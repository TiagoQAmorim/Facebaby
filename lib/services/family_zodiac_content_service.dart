import 'dart:convert';

import 'package:flutter/services.dart';

import '../i18n/app_i18n.dart';
import '../utils/zodiac_keys.dart';

enum FamilyZodiacRole { father, mother, baby }

/// Textos de signos (pai, mãe, bebê) por idioma — fonte: DOCX do portal.
class FamilyZodiacContentService {
  FamilyZodiacContentService._();
  static final FamilyZodiacContentService instance = FamilyZodiacContentService._();

  static const _assetPath = 'assets/data/family_zodiac_content.json';

  Map<String, dynamic>? _byLang;

  Future<void> ensureLoaded() async {
    if (_byLang != null) return;
    final raw = await rootBundle.loadString(_assetPath);
    _byLang = jsonDecode(raw) as Map<String, dynamic>;
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

  /// Parágrafo principal do documento para o signo e papel (pai/mãe/bebê).
  String? body(AppLang lang, ZodiacId sign, FamilyZodiacRole role) {
    final langMap = _byLang?[_langKey(lang)];
    if (langMap is! Map<String, dynamic>) return null;
    final signMap = langMap[sign.name];
    if (signMap is! Map<String, dynamic>) return null;
    final text = signMap[role.name];
    if (text is! String || text.trim().isEmpty) return null;
    return text.trim();
  }
}
