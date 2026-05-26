import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../theme/app_theme.dart';

/// Barra compacta acima do campo de texto — gravando / processando / confirmação.
class VoiceRecordStatusBar extends StatelessWidget {
  const VoiceRecordStatusBar({
    super.key,
    required this.phase,
    required this.recordSeconds,
    this.previewMode = VoiceRecordPreviewMode.register,
    this.transcript,
    this.summary,
    this.onCancelRecording,
    this.onStopRecording,
    this.onConfirmRegister,
    this.onDiscardPreview,
    this.onAskAiInstead,
    this.showAskAiOnRegister = false,
    this.busy = false,
  });

  final VoiceRecordBarPhase phase;
  final VoiceRecordPreviewMode previewMode;
  final int recordSeconds;
  final String? transcript;
  final String? summary;
  final VoidCallback? onCancelRecording;
  final VoidCallback? onStopRecording;
  final VoidCallback? onConfirmRegister;
  final VoidCallback? onDiscardPreview;
  final VoidCallback? onAskAiInstead;
  final bool showAskAiOnRegister;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    switch (phase) {
      case VoiceRecordBarPhase.recording:
        return const SizedBox.shrink();
      case VoiceRecordBarPhase.processing:
        return _ProcessingBar(label: s.aiVoiceProcessing);
      case VoiceRecordBarPhase.preview:
        if (previewMode == VoiceRecordPreviewMode.registerFailed) {
          return _RegisterFailedBar(
            understoodLabel: s.aiVoiceUnderstood(transcript ?? ''),
            title: s.aiVoiceNotARegisterTitle,
            hint: s.aiVoiceRegisterHint,
            cancelLabel: s.cancel,
            askAiLabel: s.aiVoiceAskAiInstead,
            onCancel: busy ? null : onDiscardPreview,
            onAskAi: busy ? null : onAskAiInstead,
          );
        }
        return _PreviewBar(
          understoodLabel: s.aiVoiceUnderstood(transcript ?? ''),
          confirmTitle: s.aiVoiceConfirmTitle,
          summary: summary ?? '',
          confirmLabel: s.aiVoiceConfirm,
          cancelLabel: s.cancel,
          askAiLabel: s.aiVoiceAskAiInstead,
          onConfirm: busy ? null : onConfirmRegister,
          onCancel: busy ? null : onDiscardPreview,
          onAskAi: showAskAiOnRegister && !busy ? onAskAiInstead : null,
          busy: busy,
        );
      case VoiceRecordBarPhase.idle:
        return const SizedBox.shrink();
    }
  }
}

enum VoiceRecordBarPhase { idle, recording, processing, preview }

enum VoiceRecordPreviewMode { register, registerFailed }

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.label,
    required this.cancelLabel,
    this.onCancel,
    this.onStop,
  });

  final String label;
  final String cancelLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFEBEE),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFE53935),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6A1B9A),
                ),
              ),
            ),
            TextButton(onPressed: onCancel, child: Text(cancelLabel)),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: onStop,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child:
                  const Icon(Icons.stop_rounded, size: 20, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessingBar extends StatelessWidget {
  const _ProcessingBar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF7B1FA2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black.withAlpha(170),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterFailedBar extends StatelessWidget {
  const _RegisterFailedBar({
    required this.understoodLabel,
    required this.title,
    required this.hint,
    required this.cancelLabel,
    required this.askAiLabel,
    this.onCancel,
    this.onAskAi,
  });

  final String understoodLabel;
  final String title;
  final String hint;
  final String cancelLabel;
  final String askAiLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onAskAi;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(245),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              understoodLabel,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3D2A4F),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: Color(0xFF4A148C),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: Colors.black.withAlpha(170),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: Text(cancelLabel),
                  ),
                ),
                if (onAskAi != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onAskAi,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                      ),
                      child: Text(askAiLabel),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBar extends StatelessWidget {
  const _PreviewBar({
    required this.understoodLabel,
    required this.confirmTitle,
    required this.summary,
    required this.confirmLabel,
    required this.cancelLabel,
    this.askAiLabel,
    this.onConfirm,
    this.onCancel,
    this.onAskAi,
    this.busy = false,
  });

  final String understoodLabel;
  final String confirmTitle;
  final String summary;
  final String confirmLabel;
  final String cancelLabel;
  final String? askAiLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final VoidCallback? onAskAi;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(245),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              understoodLabel,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3D2A4F),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              confirmTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: Color(0xFF4A148C),
              ),
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                summary,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: Colors.black.withAlpha(170),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: Text(cancelLabel),
                  ),
                ),
                if (onAskAi != null && askAiLabel != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onAskAi,
                      child: Text(
                        askAiLabel!,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.ctaPrimary,
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(confirmLabel),
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
