import '../services/measurement_units_prefs.dart';

abstract final class MeasurementFormat {
  MeasurementFormat._();

  static String _comma(String s) => s.replaceAll('.', ',');

  static double _kgToLb(double kg) => kg * 2.2046226218;
  static double _kgToSt(double kg) => _kgToLb(kg) / 14.0;
  static double _cmToIn(double cm) => cm / 2.54;
  static double _mlToUsFloz(double ml) => ml / 29.5735295625;
  static double _mlToUkFloz(double ml) => ml / 28.4130625;
  static double _cToF(double c) => (c * 9.0 / 5.0) + 32.0;
  static double _lbToKg(double lb) => lb / 2.2046226218;
  static double _stToKg(double st) => _lbToKg(st * 14.0);
  static double _inToCm(double inch) => inch * 2.54;
  static double _usFlozToMl(double floz) => floz * 29.5735295625;
  static double _ukFlozToMl(double floz) => floz * 28.4130625;
  static double _fToC(double f) => (f - 32.0) * 5.0 / 9.0;

  static double? _parseNum(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return null;
    // remove unidades e espaços comuns
    final cleaned = t
        .replaceAll('kg', '')
        .replaceAll('lb', '')
        .replaceAll('st', '')
        .replaceAll('cm', '')
        .replaceAll('pol', '')
        .replaceAll('in', '')
        .replaceAll('ml', '')
        .replaceAll('uk fl oz', '')
        .replaceAll('us fl oz', '')
        .replaceAll('fl oz', '')
        .replaceAll('°c', '')
        .replaceAll('ºc', '')
        .replaceAll('°f', '')
        .replaceAll('ºf', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  /// Converte entrada do usuário (unidade atual) para kg (base do banco).
  static double? parseWeightToKg(String raw) {
    final v = _parseNum(raw);
    if (v == null) return null;
    return switch (MeasurementUnitsPrefs.weight.value) {
      WeightUnit.kg => v,
      WeightUnit.lb => _lbToKg(v),
      WeightUnit.st => _stToKg(v),
    };
  }

  /// Converte entrada do usuário (unidade atual) para cm (base do banco).
  static double? parseLengthToCm(String raw) {
    final v = _parseNum(raw);
    if (v == null) return null;
    return switch (MeasurementUnitsPrefs.length.value) {
      LengthUnit.cm => v,
      LengthUnit.inch => _inToCm(v),
    };
  }

  /// Converte entrada do usuário (unidade atual) para ml (base do banco).
  static double? parseLiquidToMl(String raw) {
    final v = _parseNum(raw);
    if (v == null) return null;
    return switch (MeasurementUnitsPrefs.liquid.value) {
      LiquidUnit.ml => v,
      LiquidUnit.ukFloz => _ukFlozToMl(v),
      LiquidUnit.usFloz => _usFlozToMl(v),
    };
  }

  /// Converte entrada do usuário (unidade atual) para ºC (base).
  static double? parseTempToC(String raw) {
    final v = _parseNum(raw);
    if (v == null) return null;
    return switch (MeasurementUnitsPrefs.temperature.value) {
      TemperatureUnit.c => v,
      TemperatureUnit.f => _fToC(v),
    };
  }

  static String weight(double? kg, {int decimalsKg = 2}) {
    if (kg == null) return '—';
    final v = kg;
    switch (MeasurementUnitsPrefs.weight.value) {
      case WeightUnit.kg:
        return '${_comma(v.toStringAsFixed(decimalsKg))} kg';
      case WeightUnit.lb:
        return '${_comma(_kgToLb(v).toStringAsFixed(1))} lb';
      case WeightUnit.st:
        return '${_comma(_kgToSt(v).toStringAsFixed(1))} st';
    }
  }

  static String length(double? cm, {int decimalsCm = 0}) {
    if (cm == null) return '—';
    final v = cm;
    switch (MeasurementUnitsPrefs.length.value) {
      case LengthUnit.cm:
        return '${_comma(v.toStringAsFixed(decimalsCm))} cm';
      case LengthUnit.inch:
        return '${_comma(_cmToIn(v).toStringAsFixed(1))} pol';
    }
  }

  static String liquid(double? ml) {
    if (ml == null) return '—';
    final v = ml;
    switch (MeasurementUnitsPrefs.liquid.value) {
      case LiquidUnit.ml:
        return '${_comma(v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1))} ml';
      case LiquidUnit.ukFloz:
        return '${_comma(_mlToUkFloz(v).toStringAsFixed(1))} uk fl oz';
      case LiquidUnit.usFloz:
        return '${_comma(_mlToUsFloz(v).toStringAsFixed(1))} us fl oz';
    }
  }

  static String temperature(double? celsius) {
    if (celsius == null) return '—';
    final v = celsius;
    switch (MeasurementUnitsPrefs.temperature.value) {
      case TemperatureUnit.c:
        return '${_comma(v.toStringAsFixed(1))} ºC';
      case TemperatureUnit.f:
        return '${_comma(_cToF(v).toStringAsFixed(1))} ºF';
    }
  }
}

