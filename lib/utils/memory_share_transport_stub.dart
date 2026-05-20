import 'dart:typed_data';

Future<void> shareTempBytes(Uint8List data, String fileName, String mimeType) async {
  throw UnsupportedError('Partilhar ficheiro só está disponível na app (Android/iOS/desktop).');
}

Future<String> savePdfBytes(Uint8List data, String fileName) async {
  throw UnsupportedError('Guardar PDF só está disponível na app instalada.');
}

Future<void> sharePdfFile(String filePath) async {
  throw UnsupportedError('Partilhar PDF só está disponível na app instalada.');
}
