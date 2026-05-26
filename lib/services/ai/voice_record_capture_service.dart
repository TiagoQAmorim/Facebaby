import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'voice_record_file_stub.dart'
    if (dart.library.io) 'voice_record_file_io.dart';

/// Grava áudio curto (máx. 20s) para registro por voz.
class VoiceRecordCaptureService {
  VoiceRecordCaptureService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  static const maxDuration = Duration(seconds: 20);

  final AudioRecorder _recorder;
  Timer? _limitTimer;
  String? _path;

  Future<VoiceMicPermissionResult> ensureMicrophonePermission() async {
    if (kIsWeb) {
      return VoiceMicPermissionResult.deniedPermanently;
    }
    final status = await Permission.microphone.request();
    if (status.isGranted) return VoiceMicPermissionResult.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return VoiceMicPermissionResult.deniedPermanently;
    }
    return VoiceMicPermissionResult.denied;
  }

  Future<void> startRecording() async {
    if (await _recorder.isRecording()) return;

    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _path!,
    );

    _limitTimer?.cancel();
    _limitTimer = Timer(maxDuration, () {
      // Caller should listen and stop; flag via isRecording check.
    });
  }

  Future<bool> get isRecording => _recorder.isRecording();

  Future<VoiceCapturedAudio?> stopRecording() async {
    _limitTimer?.cancel();
    _limitTimer = null;
    final path = await _recorder.stop();
    final filePath = path ?? _path;
    _path = null;
    if (filePath == null || filePath.isEmpty) return null;

    final bytes = await readVoiceFileBytes(filePath);
    if (bytes == null || bytes.isEmpty) return null;

    final mimeType = voiceRecordMimeType();
    return VoiceCapturedAudio(
      bytes: bytes,
      mimeType: mimeType,
      base64: base64Encode(bytes),
    );
  }

  Future<void> cancelRecording() async {
    _limitTimer?.cancel();
    _limitTimer = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    final p = _path;
    _path = null;
    if (p != null) {
      await deleteVoiceFile(p);
    }
  }

  void dispose() {
    _limitTimer?.cancel();
    _recorder.dispose();
  }
}

class VoiceCapturedAudio {
  const VoiceCapturedAudio({
    required this.bytes,
    required this.mimeType,
    required this.base64,
  });

  final List<int> bytes;
  final String mimeType;
  final String base64;
}

enum VoiceMicPermissionResult { granted, denied, deniedPermanently }
