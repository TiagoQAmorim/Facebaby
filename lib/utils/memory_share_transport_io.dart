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
