import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../i18n/app_i18n.dart';
import '../../utils/ai_nanny_tts_text.dart';
import '../../utils/app_tts_locale.dart';
import 'ai_nanny_service.dart';
import 'ai_nanny_tts_playback_state.dart';

/// Resultado legado (compatibilidade).
enum AiNannySpeakResult {
  neural,
  skipped,
  neuralUnavailable,
}

class _CachedAudio {
  _CachedAudio({
    required this.bytes,
    required this.mimeType,
    this.filePath,
  });

  final Uint8List bytes;
  final String mimeType;
  final String? filePath;
}

/// TTS neural da IA Babá: cache por mensagem, estados e reprodução não bloqueante.
class AiNannyTtsService extends ChangeNotifier {
  AiNannyTtsService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    AudioPlayer? player,
  })  : _functions = functions ??
            FirebaseFunctions.instanceFor(region: aiNannyFunctionsRegion),
        _auth = auth ?? FirebaseAuth.instance,
        _player = player ?? AudioPlayer() {
    unawaited(_initPlayback());
    _playerSub = _player.onPlayerStateChanged.listen(_onPlayerStateChanged);
    _completeSub = _player.onPlayerComplete.listen(_onPlayerComplete);
  }

  static const String _callableName = 'synthesizeAiNannySpeech';
  static bool _globalAudioContextReady = false;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final AudioPlayer _player;
  final Map<String, _CachedAudio> _cache = {};

  AppLang _lang = AppLang.pt;
  String? _activeMessageId;
  AiNannyTtsPlaybackState _activeState = AiNannyTtsPlaybackState.idle;
  int _generation = 0;
  StreamSubscription<PlayerState>? _playerSub;
  StreamSubscription<void>? _completeSub;

  /// Mensagem em foco (loading/playing/paused/error).
  String? get activeMessageId => _activeMessageId;

  AiNannyTtsPlaybackState playbackStateFor(String messageId) {
    if (_activeMessageId == messageId) return _activeState;
    return AiNannyTtsPlaybackState.idle;
  }

  bool isCached(String messageId) => _cache.containsKey(messageId);

  bool get isSpeaking =>
      _activeState == AiNannyTtsPlaybackState.playing ||
      _activeState == AiNannyTtsPlaybackState.loading;

  void setLanguage(AppLang lang) {
    if (_lang == lang) return;
    _lang = lang;
  }

  /// Pré-carrega áudio; com [autoPlay], toca assim que estiver pronto.
  Future<void> prepare({
    required String messageId,
    required String text,
    AppLang? language,
    bool autoPlay = false,
  }) async {
    if (kIsWeb) return;
    final cleaned = prepareAiNannyTtsText(text);
    if (cleaned.isEmpty) return;
    if (language != null) setLanguage(language);

    final gen = ++_generation;
    _activeMessageId = messageId;

    if (_cache.containsKey(messageId)) {
      debugPrint(
        'AiNannyTts: cache hit messageId=$messageId chars=${cleaned.length}',
      );
      if (autoPlay && _isCurrent(gen)) {
        await _playFromCache(messageId, generation: gen);
      } else {
        _setActiveState(AiNannyTtsPlaybackState.idle);
      }
      return;
    }

    _setActiveState(AiNannyTtsPlaybackState.loading);
    final sw = Stopwatch()..start();
    debugPrint(
      'AiNannyTts: TTS request start messageId=$messageId '
      'chars=${cleaned.length} autoPlay=$autoPlay',
    );

    try {
      final entry = await _fetchAudio(cleaned);
      sw.stop();
      if (!_isCurrent(gen) || _activeMessageId != messageId) return;

      if (entry == null) {
        debugPrint(
          'AiNannyTts: TTS failed messageId=$messageId '
          'durationMs=${sw.elapsedMilliseconds} chars=${cleaned.length}',
        );
        _setActiveState(AiNannyTtsPlaybackState.error);
        return;
      }

      _cache[messageId] = entry;
      debugPrint(
        'AiNannyTts: TTS success messageId=$messageId '
        'durationMs=${sw.elapsedMilliseconds} bytes=${entry.bytes.length}',
      );

      if (autoPlay) {
        await _playFromCache(messageId, generation: gen);
      } else {
        _setActiveState(AiNannyTtsPlaybackState.idle);
      }
    } catch (e, st) {
      sw.stop();
      debugPrint(
        'AiNannyTts: TTS error messageId=$messageId '
        'durationMs=${sw.elapsedMilliseconds} $e\n$st',
      );
      if (_isCurrent(gen) && _activeMessageId == messageId) {
        _setActiveState(AiNannyTtsPlaybackState.error);
      }
    }
  }

  /// Toque no botão: play / pause / resume / retry.
  Future<void> toggleForMessage({
    required String messageId,
    required String text,
    AppLang? language,
  }) async {
    if (kIsWeb) return;
    if (language != null) setLanguage(language);

    if (_activeMessageId == messageId) {
      switch (_activeState) {
        case AiNannyTtsPlaybackState.playing:
          await pause();
          return;
        case AiNannyTtsPlaybackState.paused:
          await resume();
          return;
        case AiNannyTtsPlaybackState.loading:
          return;
        case AiNannyTtsPlaybackState.error:
          await prepare(
            messageId: messageId,
            text: text,
            language: language,
            autoPlay: true,
          );
          return;
        case AiNannyTtsPlaybackState.idle:
          break;
      }
    }

    await stop();
    if (_cache.containsKey(messageId)) {
      _activeMessageId = messageId;
      final gen = ++_generation;
      await _playFromCache(messageId, generation: gen);
      return;
    }

    await prepare(
      messageId: messageId,
      text: text,
      language: language,
      autoPlay: true,
    );
  }

  Future<void> pause() async {
    if (_activeState != AiNannyTtsPlaybackState.playing) return;
    try {
      await _player.pause();
      _setActiveState(AiNannyTtsPlaybackState.paused);
      debugPrint('AiNannyTts: playback paused messageId=$_activeMessageId');
    } catch (e) {
      debugPrint('AiNannyTts: pause error $e');
    }
  }

  Future<void> resume() async {
    if (_activeState != AiNannyTtsPlaybackState.paused) return;
    try {
      await _player.resume();
      _setActiveState(AiNannyTtsPlaybackState.playing);
      debugPrint('AiNannyTts: playback resumed messageId=$_activeMessageId');
    } catch (e) {
      debugPrint('AiNannyTts: resume error $e');
      _setActiveState(AiNannyTtsPlaybackState.error);
    }
  }

  /// API legada — delega para [prepare] com autoPlay.
  Future<AiNannySpeakResult> speak(String text, {AppLang? language}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || kIsWeb) return AiNannySpeakResult.skipped;

    final messageId = 'legacy-${trimmed.hashCode}';
    await prepare(
      messageId: messageId,
      text: trimmed,
      language: language,
      autoPlay: true,
    );

    if (_activeState == AiNannyTtsPlaybackState.error) {
      return AiNannySpeakResult.neuralUnavailable;
    }
    if (_cache.containsKey(messageId) ||
        _activeState == AiNannyTtsPlaybackState.playing ||
        _activeState == AiNannyTtsPlaybackState.loading) {
      return AiNannySpeakResult.neural;
    }
    return AiNannySpeakResult.neuralUnavailable;
  }

  Future<void> stop() async {
    _generation++;
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('AiNannyTts: stop player error $e');
    }
    _setActiveState(AiNannyTtsPlaybackState.idle);
    _activeMessageId = null;
  }

  @override
  Future<void> dispose() async {
    _generation++;
    await _playerSub?.cancel();
    await _completeSub?.cancel();
    try {
      await _player.stop();
      await _player.dispose();
    } catch (_) {}
    for (final entry in _cache.values) {
      await _deleteFile(entry.filePath);
    }
    _cache.clear();
    super.dispose();
  }

  void _setActiveState(AiNannyTtsPlaybackState state) {
    _activeState = state;
    notifyListeners();
  }

  bool _isCurrent(int generation) => generation == _generation;

  void _onPlayerStateChanged(PlayerState state) {
    if (_activeMessageId == null) return;
    if (state == PlayerState.paused &&
        _activeState == AiNannyTtsPlaybackState.playing) {
      _setActiveState(AiNannyTtsPlaybackState.paused);
    }
  }

  void _onPlayerComplete(void _) {
    if (_activeMessageId == null) return;
    debugPrint('AiNannyTts: playback complete messageId=$_activeMessageId');
    _setActiveState(AiNannyTtsPlaybackState.idle);
    _activeMessageId = null;
  }

  Future<void> _initPlayback() async {
    if (kIsWeb || _globalAudioContextReady) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
      _globalAudioContextReady = true;
    } catch (e) {
      debugPrint('AiNannyTts: audio context $e');
    }
    try {
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.setVolume(1.0);
    } catch (e) {
      debugPrint('AiNannyTts: player init $e');
    }
  }

  Future<_CachedAudio?> _fetchAudio(String text) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('AiNannyTts: sem usuário autenticado');
      return null;
    }
    try {
      await user.getIdToken(true);
    } catch (e) {
      debugPrint('AiNannyTts: getIdToken $e');
    }

    final callable = _functions.httpsCallable(
      _callableName,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
    );
    final result = await callable.call({
      'text': text,
      'locale': appLocaleApiCode(_lang),
    });

    final data = result.data;
    if (data is! Map) return null;
    final m = Map<String, dynamic>.from(data);
    final b64 = '${m['audioBase64'] ?? ''}'.trim();
    if (b64.isEmpty) return null;

    final mimeType = '${m['mimeType'] ?? 'audio/mpeg'}'.trim();
    if (kDebugMode) {
      debugPrint(
        'AiNannyTts: TTS response model=${m['model']} '
        'voice=${m['voice']} b64Len=${b64.length}',
      );
    }

    final bytes = Uint8List.fromList(base64Decode(b64));
    if (bytes.isEmpty) return null;

    String? filePath;
    if (!kIsWeb) {
      try {
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/ai_nanny_${DateTime.now().millisecondsSinceEpoch}.mp3',
        );
        await file.writeAsBytes(bytes, flush: true);
        filePath = file.path;
      } catch (e) {
        debugPrint('AiNannyTts: temp file write $e');
      }
    }

    return _CachedAudio(bytes: bytes, mimeType: mimeType, filePath: filePath);
  }

  Future<void> _playFromCache(
    String messageId, {
    required int generation,
  }) async {
    final entry = _cache[messageId];
    if (entry == null || !_isCurrent(generation)) return;

    await _initPlayback();
    _setActiveState(AiNannyTtsPlaybackState.loading);

    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.stop();

      final Source source;
      if (entry.filePath != null && await File(entry.filePath!).exists()) {
        source = DeviceFileSource(entry.filePath!);
      } else {
        source = BytesSource(entry.bytes, mimeType: entry.mimeType);
      }

      await _player.setSource(source);
      await _player.setVolume(1.0);

      final playSw = Stopwatch()..start();
      await _player.resume();
      playSw.stop();

      if (!_isCurrent(generation) || _activeMessageId != messageId) return;

      _setActiveState(AiNannyTtsPlaybackState.playing);
      debugPrint(
        'AiNannyTts: playback start messageId=$messageId '
        'startLatencyMs=${playSw.elapsedMilliseconds}',
      );
    } catch (e, st) {
      debugPrint('AiNannyTts: playback error messageId=$messageId $e\n$st');
      if (_isCurrent(generation) && _activeMessageId == messageId) {
        _setActiveState(AiNannyTtsPlaybackState.error);
      }
    }
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
