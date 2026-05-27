import '../../i18n/app_i18n.dart';

/// Fases de feedback visível durante processamento.
enum AiNannyProcessingPhase {
  transcribing,
  /// Após transcrição — extração estruturada de registros.
  understandingRecords,
  understanding,
  identifying,
  preparing,
  slowWarning,
  verySlow,
  showingResults,
  idle,
}

extension AiNannyProcessingPhaseLabel on AiNannyProcessingPhase {
  String label(S s) => switch (this) {
        AiNannyProcessingPhase.transcribing => s.aiPhaseTranscribing,
        AiNannyProcessingPhase.understandingRecords =>
            s.aiPhaseUnderstandingRecords,
        AiNannyProcessingPhase.understanding => s.aiPhaseUnderstanding,
        AiNannyProcessingPhase.identifying => s.aiPhaseIdentifying,
        AiNannyProcessingPhase.preparing => s.aiPhasePreparing,
        AiNannyProcessingPhase.slowWarning => s.aiPhaseSlowWarning,
        AiNannyProcessingPhase.verySlow => s.aiPhaseVerySlow,
        AiNannyProcessingPhase.showingResults => s.aiPhaseShowingResults,
        AiNannyProcessingPhase.idle => '',
      };
}

typedef AiNannyProgressCallback = void Function(AiNannyProcessingPhase phase);
