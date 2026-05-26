import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_message_model.dart';
import '../../models/ai/voice_record_interpretation.dart';
import '../../services/ai/ai_nanny_service.dart';
import '../../services/ai/ai_nanny_tts_service.dart';
import '../../services/ai/voice_record_api_service.dart';
import '../../services/ai/voice_record_capture_service.dart';
import '../../services/ai/ai_nanny_turn_service.dart';
import '../../utils/voice_record_infer.dart';
import '../../services/ai/ai_chat_session.dart';
import '../../services/home_prefs.dart';
import '../../services/ai/ai_nanny_tts_playback_state.dart';
import '../../widgets/ai/ai_nanny_input_bar.dart';
import '../../widgets/ai/ai_nanny_listen_button.dart';
import '../../widgets/ai/voice_record_status_bar.dart';
import '../../widgets/ai/ai_nanny_records_confirm_sheet.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../services/ai/ai_nanny_record_confirm_flow.dart';
import 'ai_baby_history_page.dart';

/// IA Babá — chat (Fase 3: arquitetura com services/repository, resposta mock).
class AiNannyScreen extends StatefulWidget {
  const AiNannyScreen({super.key});

  @override
  State<AiNannyScreen> createState() => _AiNannyScreenState();
}

class _AiNannyScreenState extends State<AiNannyScreen> {
  static const _iconAsset = 'assets/ai/ia_baba_button.png';

  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final AiNannyService _service = AiNannyService();
  late final AiNannyTurnService _turn;
  final _voiceCapture = VoiceRecordCaptureService();
  final _voiceApi = VoiceRecordApiService();
  final _tts = AiNannyTtsService();

  bool _typing = false;
  bool _sending = false;
  VoiceRecordBarPhase _voicePhase = VoiceRecordBarPhase.idle;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  bool _finishRecordingInProgress = false;
  StreamSubscription<List<AiMessage>>? _messagesSub;

  AppLang _langOf(BuildContext context) => AppI18nScope.of(context).lang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tts.setLanguage(_langOf(context));
  }

  @override
  void initState() {
    super.initState();
    _turn = AiNannyTurnService(nanny: _service);
    _messagesSub = _service.watchMessages().listen((_) {
      if (!mounted) return;
      _scrollToEnd(jump: true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_prepareChatSession(S.of(context)));
    });
    _service.watchTyping().listen((typing) {
      if (!mounted) return;
      setState(() => _typing = typing);
      if (!typing) _scrollToEnd();
    });
  }

  Future<void> _prepareChatSession(S s) async {
    if (AiChatSession.needsFreshChatOnOpen) {
      AiChatSession.markChatPreparedForLaunch();
      unawaited(_service.resetForNewAppSession(s.aiNannyWelcomeMessage));
    } else {
      await _service.ensureWelcomeMessage(s.aiNannyWelcomeMessage);
    }
    if (!mounted) return;
    _scrollToEnd(jump: true);
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _recordTimer?.cancel();
    unawaited(_voiceCapture.cancelRecording());
    unawaited(_tts.dispose());
    _voiceCapture.dispose();
    _service.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onMicTap(S s) {
    if (_voicePhase == VoiceRecordBarPhase.recording) {
      unawaited(_finishRecording(s));
      return;
    }
    unawaited(_startRecording(s));
  }

  Future<void> _startRecording(S s) async {
    if (_voicePhase == VoiceRecordBarPhase.recording ||
        _voicePhase == VoiceRecordBarPhase.processing ||
        _typing ||
        _sending) {
      return;
    }

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.aiVoiceMicWebUnavailable)),
      );
      return;
    }

    try {
      final perm = await _voiceCapture.ensureMicrophonePermission();
      if (!mounted) return;
      if (perm != VoiceMicPermissionResult.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.aiVoiceMicDenied)),
        );
        return;
      }

      await _voiceCapture.startRecording();
      if (!mounted) return;

      _recordSeconds = 0;
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (!mounted) {
          t.cancel();
          return;
        }
        final next = _recordSeconds + 1;
        if (next >= VoiceRecordCaptureService.maxDuration.inSeconds) {
          t.cancel();
          await _finishRecording(s);
          return;
        }
        setState(() => _recordSeconds = next);
      });
      setState(() => _voicePhase = VoiceRecordBarPhase.recording);
    } catch (_) {
      await _voiceCapture.cancelRecording();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.aiVoiceRecordFailed)),
      );
    }
  }

  Future<void> _cancelRecording(S s) async {
    _recordTimer?.cancel();
    await _voiceCapture.cancelRecording();
    if (!mounted) return;
    setState(() {
      _voicePhase = VoiceRecordBarPhase.idle;
      _recordSeconds = 0;
    });
  }

  Future<void> _finishRecording(S s) async {
    if (_finishRecordingInProgress) return;
    _recordTimer?.cancel();

    final nativeRecording = await _voiceCapture.isRecording;
    final uiRecording = _voicePhase == VoiceRecordBarPhase.recording;
    if (!uiRecording && !nativeRecording) {
      if (mounted) {
        setState(() {
          _voicePhase = VoiceRecordBarPhase.idle;
          _recordSeconds = 0;
        });
      }
      return;
    }

    _finishRecordingInProgress = true;
    if (!mounted) {
      _finishRecordingInProgress = false;
      return;
    }
    setState(() => _voicePhase = VoiceRecordBarPhase.processing);

    final locale = _langOf(context);
    try {
      final audio = await _voiceCapture.stopRecording();
      if (audio == null) {
        throw const VoiceRecordApiException('Áudio vazio.');
      }

      final babyName =
          (CurrentBabyController.instance.currentBabyRow?['name'] as String?)
              ?.trim();
      final result = await _voiceApi.processAudio(
        audioBase64: audio.base64,
        mimeType: audio.mimeType,
        babyName: babyName,
        locale: locale,
      );

      if (!mounted) return;

      final transcript = result.transcript;
      final interp = enhanceVoiceRecordInterpretation(
        interpretation: result.interpretation,
        transcript: transcript,
      );
      setState(() {
        _voicePhase = VoiceRecordBarPhase.idle;
        _recordSeconds = 0;
      });
      await _handleUserTurn(
        s,
        transcript,
        interpretationHint: interp,
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? s.aiVoiceRecordFailed)),
      );
      setState(() => _voicePhase = VoiceRecordBarPhase.idle);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.aiVoiceRecordFailed)),
      );
      setState(() => _voicePhase = VoiceRecordBarPhase.idle);
    } finally {
      _finishRecordingInProgress = false;
    }
  }

  Future<void> _handleUserTurn(
    S s,
    String text, {
    VoiceRecordInterpretation? interpretationHint,
    bool tryRegister = true,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending || _typing) return;

    setState(() => _sending = true);
    _scrollToEnd();

    String? answerToSpeak;
    try {
      final babyRow = CurrentBabyController.instance.currentBabyRow;
      final babyName = (babyRow?['name'] as String?)?.trim();
      final turn = await _turn.processTurn(
        userText: trimmed,
        strings: s,
        locale: _langOf(context),
        babyName: babyName,
        babyCloudId: CurrentBabyController.instance.currentBabyCloudId,
        userId: FirebaseAuth.instance.currentUser?.uid,
        interpretationHint: interpretationHint,
        tryRegister: tryRegister,
      );
      if (!mounted) return;

      if (turn.recordsBundle != null) {
        final bundle = turn.recordsBundle!;
        final confirmMode = await showAiNannyRecordsConfirmSheet(
          context: context,
          bundle: bundle,
        );
        if (!mounted) return;
        if (confirmMode != null) {
          final after = await _turn.saveAfterConfirmation(
            bundle: bundle,
            mode: confirmMode,
            strings: s,
            locale: _langOf(context),
            babyName: babyName,
            babyCloudId: CurrentBabyController.instance.currentBabyCloudId,
            userId: FirebaseAuth.instance.currentUser?.uid,
          );
          if (!mounted) return;
          if (after.partialSaveSnack != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(after.partialSaveSnack!)),
            );
          }
          if (after.needsClarification && after.registerSnack != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(after.registerSnack!),
                duration: const Duration(seconds: 7),
              ),
            );
          } else if (after.registerApplied && after.registerSnack != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(after.registerSnack!)),
            );
          }
          answerToSpeak = after.aiAnswer;
        }
      }

      if (turn.partialSaveSnack != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(turn.partialSaveSnack!)),
        );
      }
      if (turn.needsClarification && turn.registerSnack != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(turn.registerSnack!),
            duration: const Duration(seconds: 7),
          ),
        );
      } else if (turn.registerApplied && turn.registerSnack != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(turn.registerSnack!)),
        );
      } else if (turn.registerError != null &&
          turn.registerError!.trim().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(turn.registerError!)),
        );
      }
      answerToSpeak ??= turn.aiAnswer;
      _scrollToEnd();
    } on AiDailyLimitReachedException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.aiNannyDailyLimitMessage)),
      );
    } on AiNannyCallFailedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.userMessage ?? s.aiNannyCallFailed),
          duration: const Duration(seconds: 6),
        ),
      );
    } on AiNannyNotSignedInException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.aiNannySignInRequired)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    if (mounted && answerToSpeak != null && answerToSpeak.isNotEmpty) {
      final answer = answerToSpeak;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final messageId = _aiMessageIdForAnswer(
          answer,
          _service.messagesSnapshot,
        );
        if (messageId != null) {
          unawaited(_startAudioForMessage(messageId, answer, s));
        }
      });
    }
  }

  String? _aiMessageIdForAnswer(String answer, List<AiMessage> messages) {
    final trimmed = answer.trim();
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.isAi && m.text.trim() == trimmed) return m.id;
    }
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].isAi) return messages[i].id;
    }
    return null;
  }

  /// Áudio em paralelo ao texto; auto-play se o toggle estiver ativo.
  Future<void> _startAudioForMessage(
    String messageId,
    String answer,
    S s,
  ) async {
    if (kIsWeb || !HomePrefs.aiNannyAutoReadEnabled.value) return;

    await _tts.prepare(
      messageId: messageId,
      text: answer,
      language: _langOf(context),
      autoPlay: true,
    );
    if (!mounted) return;
    if (_tts.playbackStateFor(messageId) ==
        AiNannyTtsPlaybackState.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.aiNannyTtsFailed),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _onListenTap(String messageId, String text, S s) async {
    await _tts.toggleForMessage(
      messageId: messageId,
      text: text,
      language: _langOf(context),
    );
    if (!mounted) return;
    if (_tts.playbackStateFor(messageId) ==
        AiNannyTtsPlaybackState.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.aiNannyTtsFailed),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  bool _hasDeletableHistory(List<AiMessage> messages) =>
      messages.any((m) => m.firestoreDocId != null);

  Future<void> _confirmClearChat(S s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.aiNannyClearChatConfirmTitle),
        content: Text(s.aiNannyClearChatConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            child: Text(s.aiNannyClearChat),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await _service.clearConversation();
      if (!mounted) return;
      await _service.restoreWelcomeAfterClear(s.aiNannyWelcomeMessage);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.aiNannyClearChatDone)),
      );
    } on AiNannyNotSignedInException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.aiNannySignInRequired)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.aiNannyCallFailed)),
      );
    }
  }

  Future<void> _confirmDeleteExchange(S s, AiMessage message) async {
    final docId = message.firestoreDocId;
    if (docId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.aiNannyDeleteExchange),
        content: Text(s.aiNannyDeleteExchangeConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await _service.deleteExchange(docId);
    } on AiNannyNotSignedInException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.aiNannySignInRequired)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.aiNannyCallFailed)),
      );
    }
  }

  void _scrollToEnd({bool jump = false}) {
    void apply() {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (jump) {
        _scroll.jumpTo(max);
      } else {
        _scroll.animateTo(
          max,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      apply();
      if (jump) {
        WidgetsBinding.instance.addPostFrameCallback((_) => apply());
      }
    });
  }

  Future<void> _send(S s) async {
    if (_sending || _typing) return;
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await _handleUserTurn(s, text);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // Texto/enviar só no idle; microfone também ativo enquanto grava (toque para parar).
    final inputEnabled =
        !_typing && !_sending && _voicePhase == VoiceRecordBarPhase.idle;
    final micEnabled = !kIsWeb &&
        !_typing &&
        !_sending &&
        (_voicePhase == VoiceRecordBarPhase.idle ||
            _voicePhase == VoiceRecordBarPhase.recording);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: StreamBuilder<List<AiMessage>>(
                stream: _service.watchMessages(),
                initialData: const [],
                builder: (context, msgSnap) {
                  final messages = msgSnap.data ?? const [];
                  return _HeaderCard(
                    s: s,
                    showClearChat: _hasDeletableHistory(messages),
                    onOpenProfile: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AiBabyHistoryPage(),
                        ),
                      );
                    },
                    onClearChat: () => _confirmClearChat(s),
                    onAutoReadChanged: (v) =>
                        HomePrefs.setAiNannyAutoReadEnabled(v),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<List<AiMessage>>(
                stream: _service.watchMessages(),
                initialData: const [],
                builder: (context, snap) {
                  final messages = snap.data ?? const [];
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    itemCount: messages.length + (_typing ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_typing && index == messages.length) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TypingBubble(label: s.aiNannyThinking),
                        );
                      }
                      final m = messages[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MessageBubble(
                          text: m.text,
                          isUser: m.isUser,
                          messageId: m.isAi && !kIsWeb ? m.id : null,
                          tts: _tts,
                          strings: s,
                          onListenTap: m.isAi && !kIsWeb
                              ? () => _onListenTap(m.id, m.text, s)
                              : null,
                          onLongPress: m.firestoreDocId != null
                              ? () => _confirmDeleteExchange(s, m)
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_voicePhase == VoiceRecordBarPhase.processing) ...[
                    const VoiceRecordStatusBar(
                      phase: VoiceRecordBarPhase.processing,
                      recordSeconds: 0,
                    ),
                    const SizedBox(height: 8),
                  ],
                  AiNannyInputBar(
                    controller: _input,
                    hint: s.aiNannyInputHint,
                    recordingHint: s.aiVoiceRecordingHint,
                    micTapHint: s.aiVoiceTapMicHint,
                    micStopHint: s.aiVoiceTapStopHint,
                    enabled: inputEnabled,
                    onSend: () => _send(s),
                    onMicTap: () => _onMicTap(s),
                    onMicCancel: () => _cancelRecording(s),
                    micEnabled: micEnabled,
                    isRecording:
                        _voicePhase == VoiceRecordBarPhase.recording,
                    recordSeconds: _recordSeconds,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.aiNannyDisclaimer,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.35,
                      fontStyle: FontStyle.italic,
                      color: Colors.black.withAlpha(100),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.s,
    required this.onOpenProfile,
    required this.onAutoReadChanged,
    required this.onClearChat,
    this.showClearChat = false,
  });

  final S s;
  final VoidCallback onOpenProfile;
  final ValueChanged<bool> onAutoReadChanged;
  final VoidCallback onClearChat;
  final bool showClearChat;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(235),
      elevation: 0,
      shadowColor: const Color(0xFF9C27B0).withAlpha(40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: const Color(0xFFE1BEE7).withAlpha(120)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE91E8C).withAlpha(55),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  _AiNannyScreenState._iconAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF8E24AA),
                    size: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.aiNannyTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: Color(0xFF4A148C),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    s.aiNannySubtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withAlpha(165),
                    ),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 8),
                    ValueListenableBuilder<bool>(
                      valueListenable: HomePrefs.aiNannyAutoReadEnabled,
                      builder: (context, enabled, _) {
                        return InkWell(
                          onTap: () => onAutoReadChanged(!enabled),
                          borderRadius: BorderRadius.circular(12),
                          child: Row(
                            children: [
                              Icon(
                                enabled
                                    ? Icons.record_voice_over_rounded
                                    : Icons.voice_over_off_outlined,
                                size: 18,
                                color: const Color(0xFF7B1FA2),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  s.aiNannyAutoReadLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black.withAlpha(170),
                                  ),
                                ),
                              ),
                              Switch(
                                value: enabled,
                                onChanged: onAutoReadChanged,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                activeThumbColor: const Color(0xFF7B1FA2),
                                activeTrackColor:
                                    const Color(0xFF7B1FA2).withAlpha(100),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: Colors.black.withAlpha(150),
                  ),
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'clear') onClearChat();
                    if (value == 'profile') onOpenProfile();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'profile',
                      child: Text(s.aiNannyProfileButton),
                    ),
                    if (showClearChat)
                      PopupMenuItem(
                        value: 'clear',
                        child: Text(
                          s.aiNannyClearChat,
                          style: const TextStyle(
                            color: Color(0xFFC62828),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                TextButton(
                  onPressed: onOpenProfile,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7B1FA2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    s.aiNannyProfileButton,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Remove instruções internas antigas que foram coladas na mensagem do usuário.
String _userBubbleText(String text) {
  const marker = '\n\n[Instrução:';
  final i = text.indexOf(marker);
  if (i >= 0) return text.substring(0, i).trim();
  return text.trim();
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.isUser,
    this.messageId,
    this.tts,
    this.strings,
    this.onListenTap,
    this.onLongPress,
  });

  final String text;
  final bool isUser;
  final String? messageId;
  final AiNannyTtsService? tts;
  final S? strings;
  final VoidCallback? onListenTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = isUser
        ? const LinearGradient(
            colors: [Color(0xFFF8BBD0), Color(0xFFF3E5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;
    final color = isUser ? null : Colors.white.withAlpha(245);

    return Align(
      alignment: align,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: bg,
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            border: Border.all(
              color: isUser
                  ? const Color(0xFFCE93D8).withAlpha(90)
                  : Colors.white.withAlpha(200),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? _userBubbleText(text) : text,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: isUser ? FontWeight.w600 : FontWeight.w500,
                    color: const Color(0xFF3D2A4F),
                  ),
                ),
                if (onListenTap != null &&
                    messageId != null &&
                    tts != null &&
                    strings != null) ...[
                  const SizedBox(height: 10),
                  AiNannyListenButton(
                    tts: tts!,
                    messageId: messageId!,
                    strings: strings!,
                    onTap: onListenTap!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble({required this.label});

  final String label;

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(245),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: Colors.white.withAlpha(200)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _dots,
                builder: (context, _) {
                  return Row(
                    children: List.generate(3, (i) {
                      final phase = (_dots.value + i * 0.2) % 1.0;
                      final scale = 0.65 +
                          0.35 *
                              (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF8E24AA),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withAlpha(140),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

