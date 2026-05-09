// dart run tool/dump_en_leaps.dart > tool/en_leaps.json
import 'dart:convert';
import 'dart:io' show File, stderr;

void main() {
  final text = File('lib/i18n/app_i18n.dart').readAsStringSync();
  final start = text.indexOf('\n  AppLang.en: {');
  final end = text.indexOf('\n  AppLang.es: {', start);
  final block = text.substring(start + '\n  AppLang.en: {'.length, end);
  final out = <String, String>{};
  final keyRe = RegExp(r"'(devLeap[^']*|devLeaps[^']*)'\s*:");
  var i = 0;
  while (i < block.length) {
    final km = keyRe.matchAsPrefix(block, i);
    if (km == null) {
      i++;
      continue;
    }
    final key = km.group(1)!;
    var j = km.end;
    while (j < block.length && block[j].trim().isEmpty) j++;
    if (j >= block.length || block[j] != "'") {
      throw StateError('Expected quote after key $key at ${block.substring(j, j + 40)}');
    }
    j++; // skip opening '
    final buf = StringBuffer();
    while (j < block.length) {
      final c = block[j];
      if (c == r'\') {
        if (j + 1 < block.length) {
          final n = block[j + 1];
          if (n == 'n') {
            buf.write('\n');
            j += 2;
            continue;
          }
          buf.write(n);
          j += 2;
          continue;
        }
      }
      if (c == "'") {
        j++;
        break;
      }
      buf.write(c);
      j++;
    }
    while (j < block.length && block[j] != ',') j++;
    j++; // skip comma
    out[key] = buf.toString();
    i = j;
  }
  File('tool/en_leaps.json')
      .writeAsStringSync(JsonEncoder.withIndent('  ').convert(out));
  stderr.writeln('wrote ${out.length} keys to tool/en_leaps.json');
}
