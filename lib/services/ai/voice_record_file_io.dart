import 'dart:io';

Future<List<int>?> readVoiceFileBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  try {
    await file.delete();
  } catch (_) {}
  return bytes;
}

String voiceRecordMimeType() {
  return Platform.isIOS ? 'audio/m4a' : 'audio/mp4';
}

Future<void> deleteVoiceFile(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
