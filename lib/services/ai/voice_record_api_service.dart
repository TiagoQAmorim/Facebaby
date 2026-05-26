import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../i18n/app_i18n.dart';
import '../../models/ai/voice_record_interpretation.dart';
import '../../utils/app_tts_locale.dart';

const String voiceRecordFunctionsRegion = 'southamerica-east1';

/// Transcrição + interpretação via `processVoiceRecord` (sem salvar).
class VoiceRecordApiService {
  VoiceRecordApiService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions ??
            FirebaseFunctions.instanceFor(region: voiceRecordFunctionsRegion),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<VoiceRecordResult> processAudio({
    required String audioBase64,
    required String mimeType,
    String? babyName,
    AppLang locale = AppLang.pt,
  }) async {
    if (_auth.currentUser == null) {
      throw const VoiceRecordNotSignedInException();
    }

    final result = await _functions.httpsCallable('processVoiceRecord').call(
      {
        'audioBase64': audioBase64,
        'mimeType': mimeType,
        if (babyName != null && babyName.isNotEmpty) 'babyName': babyName,
        'locale': appLocaleApiCode(locale),
      },
    );

    final data = result.data;
    if (data is Map) {
      return VoiceRecordResult.fromMap(Map<String, dynamic>.from(data));
    }
    throw const VoiceRecordApiException('Resposta inválida do servidor.');
  }

  /// Interpreta texto digitado no chat (mesma lógica do áudio, sem Whisper).
  Future<VoiceRecordResult> processText({
    required String transcript,
    String? babyName,
    AppLang locale = AppLang.pt,
  }) async {
    if (_auth.currentUser == null) {
      throw const VoiceRecordNotSignedInException();
    }

    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      throw const VoiceRecordApiException('Texto vazio.');
    }

    final result = await _functions.httpsCallable('processTextRecord').call(
      {
        'transcript': trimmed,
        if (babyName != null && babyName.isNotEmpty) 'babyName': babyName,
        'locale': appLocaleApiCode(locale),
      },
    );

    final data = result.data;
    if (data is Map) {
      return VoiceRecordResult.fromMap(Map<String, dynamic>.from(data));
    }
    throw const VoiceRecordApiException('Resposta inválida do servidor.');
  }
}

class VoiceRecordNotSignedInException implements Exception {
  const VoiceRecordNotSignedInException();
}

class VoiceRecordApiException implements Exception {
  const VoiceRecordApiException(this.message);
  final String message;
}
