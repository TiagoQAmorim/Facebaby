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

