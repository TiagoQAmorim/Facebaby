import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../services/ai/ai_nanny_tts_playback_state.dart';
import '../../services/ai/ai_nanny_tts_service.dart';

/// Botão «Ouvir resposta» com estados visuais (idle/loading/playing/paused/error).
class AiNannyListenButton extends StatelessWidget {
  const AiNannyListenButton({
    super.key,
    required this.tts,
    required this.messageId,
    required this.strings,
    required this.onTap,
  });

  final AiNannyTtsService tts;
  final String messageId;
  final S strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tts,
      builder: (context, _) {
        final state = tts.playbackStateFor(messageId);
        final label = _labelFor(state, strings);
        final icon = _iconFor(state);

        return Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: state == AiNannyTtsPlaybackState.loading ? null : onTap,
            icon: state == AiNannyTtsPlaybackState.loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFF6A1B9A).withAlpha(200),
                    ),
                  )
                : Icon(icon, size: 20),
            label: Text(label),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              backgroundColor: _backgroundFor(state),
              foregroundColor: const Color(0xFF6A1B9A),
              disabledBackgroundColor:
                  const Color(0xFF7B1FA2).withAlpha(28),
              disabledForegroundColor:
                  const Color(0xFF6A1B9A).withAlpha(180),
            ),
          ),
        );
      },
    );
  }

  static String _labelFor(AiNannyTtsPlaybackState state, S s) {
    return switch (state) {
      AiNannyTtsPlaybackState.idle => s.aiVoiceListenReply,
      AiNannyTtsPlaybackState.loading => s.aiTtsPreparing,
      AiNannyTtsPlaybackState.playing => s.aiTtsPause,
      AiNannyTtsPlaybackState.paused => s.aiTtsResume,
      AiNannyTtsPlaybackState.error => s.aiTtsRetry,
    };
  }

  static IconData _iconFor(AiNannyTtsPlaybackState state) {
    return switch (state) {
      AiNannyTtsPlaybackState.idle => Icons.play_circle_fill_rounded,
      AiNannyTtsPlaybackState.loading => Icons.hourglass_top_rounded,
      AiNannyTtsPlaybackState.playing => Icons.pause_circle_filled_rounded,
      AiNannyTtsPlaybackState.paused => Icons.play_circle_fill_rounded,
      AiNannyTtsPlaybackState.error => Icons.refresh_rounded,
    };
  }

  static Color _backgroundFor(AiNannyTtsPlaybackState state) {
    return switch (state) {
      AiNannyTtsPlaybackState.error =>
        const Color(0xFFE53935).withAlpha(40),
      AiNannyTtsPlaybackState.loading =>
        const Color(0xFF7B1FA2).withAlpha(48),
      _ => const Color(0xFF7B1FA2).withAlpha(36),
    };
  }
}
