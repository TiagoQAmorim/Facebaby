import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareTempBytes(Uint8List data, String fileName, String mimeType) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$fileName';
  await File(path).writeAsBytes(data);
  await Share.shareXFiles([XFile(path, mimeType: mimeType)]);
}

/// Grava o PDF numa pasta visível ao utilizador (Downloads quando disponível; senão Documentos da app).
Future<String> savePdfBytes(Uint8List data, String fileName) async {
  Directory dir;
  try {
    final downloads = await getDownloadsDirectory();
    dir = downloads ?? await getApplicationDocumentsDirectory();
  } catch (_) {
    dir = await getApplicationDocumentsDirectory();
  }

  var safeName = fileName.trim();
  if (safeName.isEmpty) safeName = 'facebaby_album.pdf';
  if (!safeName.toLowerCase().endsWith('.pdf')) {
    safeName = '$safeName.pdf';
  }

  var path = '${dir.path}/$safeName';
  var n = 1;
  while (await File(path).exists()) {
    final base = safeName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    path = '${dir.path}/${base}_$n.pdf';
    n++;
  }

  await File(path).writeAsBytes(data);
  return path;
}
