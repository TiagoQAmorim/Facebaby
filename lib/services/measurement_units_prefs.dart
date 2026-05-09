import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LengthUnit { cm, inch }
enum WeightUnit { kg, lb, st }
enum LiquidUnit { ml, ukFloz, usFloz }
enum TemperatureUnit { c, f }

extension on LengthUnit {
  String get key => switch (this) { LengthUnit.cm => 'cm', LengthUnit.inch => 'in' };
}

extension on WeightUnit {
  String get key => switch (this) { WeightUnit.kg => 'kg', WeightUnit.lb => 'lb', WeightUnit.st => 'st' };
}

extension on LiquidUnit {
  String get key => switch (this) { LiquidUnit.ml => 'ml', LiquidUnit.ukFloz => 'uk_floz', LiquidUnit.usFloz => 'us_floz' };
}

extension on TemperatureUnit {
  String get key => switch (this) { TemperatureUnit.c => 'c', TemperatureUnit.f => 'f' };
}

abstract final class MeasurementUnitsPrefs {
  MeasurementUnitsPrefs._();

  static const _kLen = 'facebaby_units_length_v1';
  static const _kWeight = 'facebaby_units_weight_v1';
  static const _kLiquid = 'facebaby_units_liquid_v1';
  static const _kTemp = 'facebaby_units_temp_v1';

  static final ValueNotifier<LengthUnit> length = ValueNotifier<LengthUnit>(LengthUnit.cm);
  static final ValueNotifier<WeightUnit> weight = ValueNotifier<WeightUnit>(WeightUnit.kg);
  static final ValueNotifier<LiquidUnit> liquid = ValueNotifier<LiquidUnit>(LiquidUnit.ml);
  static final ValueNotifier<TemperatureUnit> temperature = ValueNotifier<TemperatureUnit>(TemperatureUnit.c);

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();

    // Se já existe pelo menos uma chave, respeita.
    final hasAny = p.containsKey(_kLen) || p.containsKey(_kWeight) || p.containsKey(_kLiquid) || p.containsKey(_kTemp);
    if (!hasAny) {
      final defaults = _defaultsByRegion();
      await p.setString(_kLen, defaults.$1.key);
      await p.setString(_kWeight, defaults.$2.key);
      await p.setString(_kLiquid, defaults.$3.key);
      await p.setString(_kTemp, defaults.$4.key);
    }

    length.value = _parseLength(p.getString(_kLen)) ?? LengthUnit.cm;
    weight.value = _parseWeight(p.getString(_kWeight)) ?? WeightUnit.kg;
    liquid.value = _parseLiquid(p.getString(_kLiquid)) ?? LiquidUnit.ml;
    temperature.value = _parseTemp(p.getString(_kTemp)) ?? TemperatureUnit.c;
  }

  static LengthUnit? _parseLength(String? k) =>
      k == null ? null : (k == 'cm' ? LengthUnit.cm : (k == 'in' ? LengthUnit.inch : null));

  static WeightUnit? _parseWeight(String? k) => switch (k) {
        'kg' => WeightUnit.kg,
        'lb' => WeightUnit.lb,
        'st' => WeightUnit.st,
        _ => null,
      };

  static LiquidUnit? _parseLiquid(String? k) => switch (k) {
        'ml' => LiquidUnit.ml,
        'uk_floz' => LiquidUnit.ukFloz,
        'us_floz' => LiquidUnit.usFloz,
        _ => null,
      };

  static TemperatureUnit? _parseTemp(String? k) => k == 'f' ? TemperatureUnit.f : (k == 'c' ? TemperatureUnit.c : null);

  static (LengthUnit, WeightUnit, LiquidUnit, TemperatureUnit) _defaultsByRegion() {
    // Regras simples, fáceis de entender:
    // - US (e alguns casos clássicos) → imperial/Fahrenheit.
    // - GB → métrico, mas “uk fl oz” em líquidos.
    // - resto → métrico (cm/kg/ml/°C).
    final loc = WidgetsBinding.instance.platformDispatcher.locale;
    final region = (loc.countryCode ?? '').trim().toUpperCase();

    if (region == 'US' || region == 'LR' || region == 'MM') {
      return (LengthUnit.inch, WeightUnit.lb, LiquidUnit.usFloz, TemperatureUnit.f);
    }
    if (region == 'GB') {
      return (LengthUnit.cm, WeightUnit.kg, LiquidUnit.ukFloz, TemperatureUnit.c);
    }
    return (LengthUnit.cm, WeightUnit.kg, LiquidUnit.ml, TemperatureUnit.c);
  }

  static Future<void> setLength(LengthUnit u) async {
    length.value = u;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLen, u.key);
  }

  static Future<void> setWeight(WeightUnit u) async {
    weight.value = u;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kWeight, u.key);
  }

  static Future<void> setLiquid(LiquidUnit u) async {
    liquid.value = u;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLiquid, u.key);
  }

  static Future<void> setTemperature(TemperatureUnit u) async {
    temperature.value = u;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTemp, u.key);
  }
}

