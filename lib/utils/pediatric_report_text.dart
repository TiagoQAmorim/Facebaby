/// Texto seguro para relatório pediátrico (PDF Helvetica / partilha).
abstract final class PediatricReportText {
  PediatricReportText._();

  static const String na = '-';
  static const String bulletPrefix = '- ';
  static const String sep = ' - ';
  static const String midDot = ', ';

  /// Substitui símbolos que costumam aparecer como quadrado com X no PDF.
  static String forPdf(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll('\u2022', '- ')
        .replaceAll('\u25cf', '- ')
        .replaceAll('\u25cb', '- ')
        .replaceAll('\u2014', ' - ')
        .replaceAll('\u2013', ' - ')
        .replaceAll('\u00b7', ', ')
        .replaceAll('\u2026', '...')
        .replaceAll('\u00a0', ' ');
  }
}
