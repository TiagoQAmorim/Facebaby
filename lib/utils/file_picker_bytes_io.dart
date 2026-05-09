import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<Uint8List?> readPlatformFileBytes(PlatformFile f) async {
  if (f.bytes != null && f.bytes!.isNotEmpty) {
    return Uint8List.fromList(f.bytes!);
  }
  final path = f.path;
  if (path == null || path.isEmpty) return null;
  try {
    return await File(path).readAsBytes();
  } catch (_) {
    return null;
  }
}
