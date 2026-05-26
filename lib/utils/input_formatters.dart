import 'package:flutter/services.dart';

class PhoneBrFormatter extends TextInputFormatter {
  // Formats as:
  // - "(##) ####-####" (10 digits)
  // - "(##) #####-####" (11 digits)
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();

    final max = digits.length >= 11 ? 11 : 10;
    for (var i = 0; i < digits.length && i < max; i++) {
      final ch = digits[i];
      if (i == 0) buf.write('(');
      if (i == 2) buf.write(') ');
      // For 11-digit numbers, split after 7th digit (e.g. 9xxxx-xxxx)
      // For 10-digit numbers, split after 6th digit (e.g. xxxx-xxxx)
      final dashAt = max == 11 ? 7 : 6;
      if (i == dashAt) buf.write('-');
      buf.write(ch);
    }

    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class DecimalPtBrFormatter extends TextInputFormatter {
  final int decimalRange;

  const DecimalPtBrFormatter({this.decimalRange = 2});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var t = newValue.text;
    // Allow digits and separators only
    t = t.replaceAll(RegExp(r'[^0-9,\.]'), '');
    // Normalize "." to "," (pt-BR)
    t = t.replaceAll('.', ',');

    final parts = t.split(',');
    if (parts.length > 2) {
      // Keep only the first comma
      t = '${parts.first},${parts.sublist(1).join()}';
    }

    if (t.contains(',')) {
      final p = t.split(',');
      final frac = p.length > 1 ? p[1] : '';
      if (frac.length > decimalRange) {
        t = '${p[0]},${frac.substring(0, decimalRange)}';
      }
    }

    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}

/// Entrada numérica estilo calculadora: só dígitos; a vírgula desloca-se à medida
/// que se digita (ex.: `170` → `1,70`; `1700` → `17,00` com 2 casas).
class ShiftDecimalPtBrFormatter extends TextInputFormatter {
  const ShiftDecimalPtBrFormatter({
    required this.decimalDigits,
    this.maxValue,
  });

  final int decimalDigits;
  final double? maxValue;

  static String formatDigits(String digits, int decimalDigits) {
    if (decimalDigits <= 0) {
      return digits.isEmpty ? '0' : digits.replaceFirst(RegExp(r'^0+'), '').ifEmpty('0');
    }
    if (digits.isEmpty) {
      return '0,${'0' * decimalDigits}';
    }
    final normalized = digits.replaceFirst(RegExp(r'^0+'), '');
    final valueDigits = normalized.isEmpty ? '0' : normalized;
    final padded = valueDigits.padLeft(decimalDigits + 1, '0');
    final splitAt = padded.length - decimalDigits;
    final whole = padded.substring(0, splitAt);
    final frac = padded.substring(splitAt);
    return '$whole,$frac';
  }

  static String formatValue(double value, int decimalDigits) {
    if (decimalDigits <= 0) return value.round().toString();
    final factor = _pow10(decimalDigits);
    return formatDigits((value * factor).round().toString(), decimalDigits);
  }

  static double? parse(String text, int decimalDigits) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 0;
    final parsed = int.tryParse(digits);
    if (parsed == null) return null;
    if (decimalDigits <= 0) return parsed.toDouble();
    return parsed / _pow10(decimalDigits);
  }

  static int _pow10(int exp) {
    var out = 1;
    for (var i = 0; i < exp; i++) {
      out *= 10;
    }
    return out;
  }

  int? get _maxScaled {
    if (maxValue == null || decimalDigits < 0) return null;
    if (decimalDigits == 0) return maxValue!.round();
    return (maxValue! * _pow10(decimalDigits)).round();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      final empty = formatDigits('', decimalDigits);
      return TextEditingValue(
        text: empty,
        selection: TextSelection.collapsed(offset: empty.length),
      );
    }

    final parsedInt = int.tryParse(digits);
    if (parsedInt == null) return oldValue;

    final maxScaled = _maxScaled;
    if (maxScaled != null && parsedInt > maxScaled) return oldValue;

    final formatted = formatDigits(digits, decimalDigits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

extension _ShiftDecimalString on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

/// Máscara `dd/mm/aaaa` — insere barras automaticamente (teclado numérico).
class DateBrMaskFormatter extends TextInputFormatter {
  const DateBrMaskFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 8) return oldValue;

    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(digits[i]);
    }

    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Converte texto `dd/mm/aaaa` em [DateTime] (só data, hora 00:00).
DateTime? parseBrDateString(String raw) {
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(raw.trim());
  if (m == null) return null;
  final day = int.tryParse(m.group(1)!);
  final month = int.tryParse(m.group(2)!);
  final year = int.tryParse(m.group(3)!);
  if (day == null || month == null || year == null) return null;
  try {
    return DateTime(year, month, day);
  } catch (_) {
    return null;
  }
}

String formatBrDate(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

class IntOnlyFormatter extends TextInputFormatter {
  const IntOnlyFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}

