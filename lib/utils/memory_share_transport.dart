import 'dart:typed_data';

import 'memory_share_transport_stub.dart'
    if (dart.library.io) 'memory_share_transport_io.dart' as tp;

Future<void> shareTempBytes(Uint8List data, String fileName, String mimeType) =>
    tp.shareTempBytes(data, fileName, mimeType);

Future<String> savePdfBytes(Uint8List data, String fileName) => tp.savePdfBytes(data, fileName);
