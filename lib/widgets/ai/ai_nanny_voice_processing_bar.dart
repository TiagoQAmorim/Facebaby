import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Barra de estado do pipeline de voz: waveform, texto e cancelar.
class AiNannyVoiceProcessingBar extends StatefulWidget {
  const AiNannyVoiceProcessingBar({
    super.key,
    required this.statusLabel,
    this.mode = AiNannyVoicePipelineBarMode.processing,
    this.onCancel,
    this.errorMessage,
    this.recordSeconds,
  });

  final String statusLabel;
  final AiNannyVoicePipelineBarMode mode;
  final VoidCallback? onCancel;
  final String? errorMessage;
  final int? recordSeconds;

  @override
  State<AiNannyVoiceProcessingBar> createState() =>
      _AiNannyVoiceProcessingBarState();
}

enum AiNannyVoicePipelineBarMode {
  recording,
  processing,
  error,
}

class _AiNannyVoiceProcessingBarState extends State<AiNannyVoiceProcessingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isError = widget.mode == AiNannyVoicePipelineBarMode.error;
    final isRecording = widget.mode == AiNannyVoicePipelineBarMode.recording;
    final bg = isError
        ? const Color(0xFFFFEBEE)
        : isRecording
            ? const Color(0xFFF3E5F5)
            : const Color(0xFFEDE7F6);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isError
              ? const Color(0xFFE53935)
              : isRecording
                  ? const Color(0xFFAB47BC)
                  : const Color(0xFFCE93D8),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (isError)
              const Icon(Icons.error_outline_rounded, color: Color(0xFFC62828))
            else
              SizedBox(
                width: 44,
                height: 28,
                child: AnimatedBuilder(
                  animation: _waveCtrl,
                  builder: (context, _) => CustomPaint(
                    painter: _WaveformPainter(
                      t: _waveCtrl.value,
                      color: isRecording
                          ? const Color(0xFFE91E8C)
                          : const Color(0xFF7B1FA2),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isError
                        ? (widget.errorMessage ?? widget.statusLabel)
                        : widget.statusLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isError
                          ? const Color(0xFFB71C1C)
                          : const Color(0xFF4A148C),
                      height: 1.3,
                    ),
                  ),
                  if (isRecording && widget.recordSeconds != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatSeconds(widget.recordSeconds!),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withAlpha(140),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.onCancel != null && !isError)
              TextButton(
                onPressed: widget.onCancel,
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            if (isError && widget.onCancel != null)
              TextButton(
                onPressed: widget.onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFC62828),
                ),
                child: Text(
                  MaterialLocalizations.of(context).okButtonLabel,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatSeconds(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    const bars = 7;
    final w = size.width / bars;
    for (var i = 0; i < bars; i++) {
      final phase = t * math.pi * 2 + i * 0.9;
      final h = (size.height * 0.25) +
          (size.height * 0.35) * (0.5 + 0.5 * math.sin(phase));
      final x = w * i + w / 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => old.t != t;
}
