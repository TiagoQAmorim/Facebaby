import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Remove EXIF, GPS e demais metadados, re-codificando apenas os pixels.
///
/// A orientação EXIF é aplicada antes de descartar os metadados ([img.bakeOrientation]).
Uint8List stripImageMetadata(Uint8List bytes, {int jpegQuality = 90}) {
  if (bytes.isEmpty) return bytes;
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final oriented = img.bakeOrientation(decoded);
    final q = jpegQuality.clamp(60, 100);
    if (oriented.hasAlpha) {
      return Uint8List.fromList(img.encodePng(oriented, level: 6));
    }
    return Uint8List.fromList(img.encodeJpg(oriented, quality: q));
  } catch (e, st) {
    debugPrint('stripImageMetadata failed: $e\n$st');
    return bytes;
  }
}
