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
            _normaliseVerse(
              text: '${item['text'] ?? ''}'.trim(),
              reference: '${item['reference'] ?? ''}'.trim(),
            ),
      ].where((v) => v.text.isNotEmpty).toList(growable: false);
    }
    _byLang = parsed;
  }

  FamilyChristianVerse _normaliseVerse({
    required String text,
    required String reference,
  }) {
    const emDash = '\u2014';
    final dashIndex = reference.indexOf(emDash);
    if (dashIndex < 0) {
      return FamilyChristianVerse(text: text, reference: reference);
    }

    final continuation = reference.substring(0, dashIndex).trim();
    final cleanReference = reference.substring(dashIndex + 1).trim();
    if (continuation.isEmpty || cleanReference.isEmpty) {
      return FamilyChristianVerse(text: text, reference: reference);
    }

    final separator = _shouldJoinWithHyphen(text, continuation) ? '-' : ' ';
    final joined =
        '$text$separator$continuation'.replaceAll(RegExp(r'\s+'), ' ').trim();
    return FamilyChristianVerse(text: joined, reference: cleanReference);
  }

  bool _shouldJoinWithHyphen(String text, String continuation) {
    if (text.isEmpty || continuation.isEmpty) return false;
    final last = text.substring(text.length - 1);
    final first = continuation.substring(0, 1);
    return RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(last) &&
        RegExp(r'[a-zà-ÿ]').hasMatch(first);
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

  /// Dia civil (meia-noite local) para o versículo do dia.
  static int _daySalt(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return d.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  /// Índice estável por dia + papel + membro (mãe/pai/bebé).
  static int _verseIndex({
    required int count,
    required int daySalt,
    required int roleSalt,
    required int memberSalt,
  }) {
    if (count <= 0) return 0;
    final mix = daySalt * 10007 + roleSalt * 7919 + memberSalt * 9973;
    return mix.abs() % count;
  }

  /// Versículo do dia: muda automaticamente a cada dia civil; aleatório mas estável no mesmo dia.
  FamilyChristianVerse? verseFor(
    AppLang lang,
    FamilyChristianRole role, {
    int? babyId,
    DateTime? calendarDay,
  }) {
    final all = verses(lang);
    if (all.isEmpty) return null;

    final day = calendarDay ?? DateTime.now();
    final daySalt = _daySalt(day);
    final roleSalt = switch (role) {
      FamilyChristianRole.mother => 1,
      FamilyChristianRole.father => 2,
      FamilyChristianRole.baby => 3,
    };
    final memberSalt = switch (role) {
      FamilyChristianRole.mother => 0,
      FamilyChristianRole.father => 0,
      FamilyChristianRole.baby => babyId ?? 0,
    };

    final index = _verseIndex(
      count: all.length,
      daySalt: daySalt,
      roleSalt: roleSalt,
      memberSalt: memberSalt,
    );
    return all[index];
  }

  String body(
    AppLang lang,
    FamilyChristianRole role, {
    int? babyId,
    DateTime? calendarDay,
  }) {
    final v = verseFor(
      lang,
      role,
      babyId: babyId,
      calendarDay: calendarDay,
    );
    if (v == null) return '';
    return '${v.text}\n\n— ${v.reference}';
  }
}
