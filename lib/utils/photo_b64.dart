import 'dart:convert';
import 'dart:typed_data';

Uint8List? decodePhotoB64(String? b64) {
  final t = b64?.trim();
  if (t == null || t.isEmpty) return null;
  try {
    return base64Decode(t);
  } catch (_) {
    return null;
  }
}

String encodePhotoB64(Uint8List bytes) => base64Encode(bytes);

