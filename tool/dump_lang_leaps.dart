/// dart run tool/dump_lang_leaps.dart pt > tool/pt_leaps.json
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final code = args.isEmpty ? 'en' : args.first;
  final order = ['pt', 'en', 'es', 'fr', 'de', 'it', 'hi', 'id', 'ja', 'ko', 'ru', 'tr', 'zh'];
  final idx = order.indexOf(code);
  if (idx < 0) {
    stderr.writeln('Unknown lang $code');
    exit(1);
  }
  final next = idx + 1 < order.length ? order[idx + 1] : null;
  final text = File('lib/i18n/app_i18n.dart').readAsStringSync();
  final startKey = '\n  AppLang.$code: {';
  final start = text.indexOf(startKey);
  if (start < 0) {
    stderr.writeln('Start not found for $code');
    exit(1);
  }
  final end = next == null
      ? text.indexOf('\n};', start)
      : text.indexOf('\n  AppLang.$next: {', start);
  if (end < 0) {
    stderr.writeln('End not found');
    exit(1);
  }
  final block = text.substring(start + startKey.length, end);
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
      throw StateError('Expected quote after key $key');
    }
    j++;
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
    j++;
    out[key] = buf.toString();
    i = j;
  }
  if (args.length > 1) {
    File(args[1]).writeAsStringSync(JsonEncoder.withIndent('  ').convert(out));
    stderr.writeln('wrote ${out.length} keys to ${args[1]}');
  } else {
    stdout.writeln(JsonEncoder.withIndent('  ').convert(out));
    stderr.writeln('keys: ${out.length}');
  }
}
