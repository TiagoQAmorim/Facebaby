import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Campo de texto + microfone (toque inicia / toque para) + enviar.
class AiNannyInputBar extends StatefulWidget {
  const AiNannyInputBar({
    super.key,
    required this.controller,
    required this.hint,
    required this.recordingHint,
    required this.micTapHint,
    required this.micStopHint,
    required this.enabled,
    required this.onSend,
    required this.onMicTap,
    required this.onMicCancel,
    this.micEnabled = true,
    this.isRecording = false,
    this.recordSeconds = 0,
  });

  final TextEditingController controller;
  final String hint;
  final String recordingHint;
  final String micTapHint;
  final String micStopHint;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onMicTap;
  final VoidCallback onMicCancel;
  final bool micEnabled;
  final bool isRecording;
  final int recordSeconds;

  @override
  State<AiNannyInputBar> createState() => _AiNannyInputBarState();
}

class _AiNannyInputBarState extends State<AiNannyInputBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didUpdateWidget(covariant AiNannyInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.isRecording && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _onMicPressed() {
    if (!widget.micEnabled) return;
    HapticFeedback.mediumImpact();
    widget.onMicTap();
  }

  @override
  Widget build(BuildContext context) {
    final recording = widget.isRecording;

    return Material(
      color: recording
          ? const Color(0xFFF3E5F5).withAlpha(250)
          : Colors.white.withAlpha(240),
      elevation: 0,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: recording
              ? const Color(0xFFAB47BC)
              : const Color(0xFFE1BEE7).withAlpha(100),
          width: recording ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (recording) ...[
              IconButton(
                onPressed: widget.micEnabled ? widget.onMicCancel : null,
                tooltip: 'Cancelar',
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.black.withAlpha(140),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
            _MicTapButton(
              enabled: widget.micEnabled,
              recording: recording,
              recordSeconds: widget.recordSeconds,
              pulse: _pulse,
              tapHint: widget.micTapHint,
              stopHint: widget.micStopHint,
              onPressed: _onMicPressed,
            ),
            Expanded(
              child: TextField(
                controller: widget.controller,
                enabled: widget.enabled && !recording,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted:
                    widget.enabled && !recording ? (_) => widget.onSend() : null,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: recording
                      ? const Color(0xFF6A1B9A)
                      : const Color(0xFF3D2A4F),
                ),
                decoration: InputDecoration(
                  hintText: recording ? widget.recordingHint : widget.hint,
                  hintStyle: TextStyle(
                    color: recording
                        ? const Color(0xFF7B1FA2)
                        : Colors.black.withAlpha(110),
                    fontWeight:
                        recording ? FontWeight.w700 : FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            FilledButton(
              onPressed: widget.enabled && !recording ? widget.onSend : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                disabledBackgroundColor: AppTheme.primaryPink.withAlpha(120),
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(14),
              ),
              child: const Icon(
                Icons.send_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicTapButton extends StatelessWidget {
  const _MicTapButton({
    required this.enabled,
    required this.recording,
    required this.recordSeconds,
    required this.pulse,
    required this.tapHint,
    required this.stopHint,
    required this.onPressed,
  });

  final bool enabled;
  final bool recording;
  final int recordSeconds;
  final AnimationController pulse;
  final String tapHint;
  final String stopHint;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: recording ? stopHint : tapHint,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (recording)
                  AnimatedBuilder(
                    animation: pulse,
                    builder: (context, child) {
                      final t = pulse.value;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          _PulseRing(scale: 1.0 + t * 0.35, opacity: 0.22),
                          _PulseRing(scale: 1.0 + (t * 0.55), opacity: 0.12),
                        ],
                      );
                    },
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: recording ? 46 : 42,
                  height: recording ? 46 : 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: recording
                          ? const [Color(0xFFE53935), Color(0xFFE91E8C)]
                          : const [Color(0xFF7B1FA2), Color(0xFF9C27B0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9C27B0)
                            .withAlpha(recording ? 100 : 50),
                        blurRadius: recording ? 16 : 8,
                        spreadRadius: recording ? 1 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    recording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: recording ? 26 : 24,
                    color: Colors.white.withAlpha(enabled ? 255 : 140),
                  ),
                ),
                if (recording && recordSeconds > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A148C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${recordSeconds}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.scale, required this.opacity});

  final double scale;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFE91E8C).withAlpha((opacity * 255).round()),
            width: 2.5,
          ),
        ),
      ),
    );
  }
}
