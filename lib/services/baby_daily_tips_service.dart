import 'dart:convert';

import 'package:flutter/services.dart';

import '../i18n/app_i18n.dart';
import '../models/baby_daily_tip.dart';
import '../utils/baby_age_months.dart';

/// Carrega `assets/data/baby_daily_tips_500.json` e escolhe uma dica estável por dia + bebé + idade.
abstract final class BabyDailyTipsService {
  BabyDailyTipsService._();

  static const _assetPath = 'assets/data/baby_daily_tips_500.json';

  static Future<List<BabyDailyTip>>? _loading;
  static List<BabyDailyTip>? _cached;

  static Future<List<BabyDailyTip>> _loadAll() async {
    final raw = await rootBundle.loadString(_assetPath);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final list = map['tips'] as List<dynamic>? ?? const [];
    return list
        .map((e) => BabyDailyTip.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((t) => t.text.trim().isNotEmpty)
        .toList(growable: false);
  }

  static String _resolvedBody(BabyDailyTip tip, AppLang lang) {
    if (lang == AppLang.pt) return tip.text.trim();
    final en = tip.textEn?.trim();
    if (en != null && en.isNotEmpty) return en;
    return tip.text.trim();
  }

  static Future<List<BabyDailyTip>> tips() {
    if (_cached != null) return Future.value(_cached);
    _loading ??= _loadAll().then((list) {
      _cached = list;
      return list;
    });
    return _loading!;
  }

  /// Idade em meses completos + desempate quando faixas se sobrepõem no JSON (ex.: 3 meses).
  static List<BabyDailyTip> tipsForAgeMonths(int ageMonths, List<BabyDailyTip> all) {
    var clamped = ageMonths < 0 ? 0 : ageMonths;
    // Acima do último bucket (30 meses): continuar a usar a faixa 24–30 meses.
    const maxBucket = 30;
    if (clamped > maxBucket) {
      clamped = maxBucket;
    }

    final overlapping = all.where((t) => clamped >= t.minAgeMonths && clamped <= t.maxAgeMonths).toList();
    if (overlapping.isEmpty) {
      final older = all.where((t) => t.phaseKey == '24_30_months').toList();
      return older.isNotEmpty ? older : all;
    }
    final bestMin = overlapping.map((t) => t.minAgeMonths).reduce((a, b) => a > b ? a : b);
    return overlapping.where((t) => t.minAgeMonths == bestMin).toList();
  }

  static int _pickIndex(int count, int daySalt, int babySalt) {
    if (count <= 0) return 0;
    final mix = daySalt * 10007 + babySalt * 7919;
    return mix.abs() % count;
  }

  /// Texto da dica ou `null` se não houver dados (fallback para i18n).
  static Future<String?> tipTextForDay({
    required DateTime? birthDate,
    required int? babyId,
    required DateTime now,
    AppLang lang = AppLang.pt,
  }) async {
    final all = await tips();
    if (all.isEmpty) return null;
    if (birthDate == null) return null;

    final ageMonths = babyCompletedMonths(birthDate, now);
    final pool = tipsForAgeMonths(ageMonths, all);
    if (pool.isEmpty) return null;

    final d = DateTime(now.year, now.month, now.day);
    final daySalt = d.year * 10000 + d.month * 100 + d.day;
    final saltId = babyId ?? 0;
    final i = _pickIndex(pool.length, daySalt, saltId);
    return _resolvedBody(pool[i], lang);
  }
}
