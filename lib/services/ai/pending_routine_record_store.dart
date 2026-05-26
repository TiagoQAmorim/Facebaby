import '../../models/ai/voice_record_interpretation.dart';

/// Rascunho de registros aguardando resposta da família (lado do peito, tipo de fralda, etc.).
class PendingRoutineRecordStore {
  PendingRoutineRecordStore._();
  static final PendingRoutineRecordStore instance = PendingRoutineRecordStore._();

  int? _babyId;
  List<VoiceRecordInterpretation> _events = [];
  String _originalTranscript = '';
  String _clarificationReplies = '';

  bool hasPendingFor(int? babyId) =>
      babyId != null && _babyId == babyId && _events.isNotEmpty;

  List<VoiceRecordInterpretation> get events => List.unmodifiable(_events);

  String get originalTranscript => _originalTranscript;

  /// Todas as respostas curtas da família desde a frase inicial (ex.: "xixi" depois "peito esquerdo").
  String get clarificationReplies => _clarificationReplies;

  void set({
    required int babyId,
    required List<VoiceRecordInterpretation> events,
    String? originalTranscript,
    bool resetReplies = false,
  }) {
    _babyId = babyId;
    _events = List.of(events);
    if (originalTranscript != null && originalTranscript.trim().isNotEmpty) {
      _originalTranscript = originalTranscript.trim();
    }
    if (resetReplies) {
      _clarificationReplies = '';
    }
  }

  void appendClarificationReply(String reply) {
    final r = reply.trim();
    if (r.isEmpty) return;
    _clarificationReplies = _clarificationReplies.isEmpty
        ? r
        : '$_clarificationReplies $r';
  }

  void clear() {
    _babyId = null;
    _events = [];
    _originalTranscript = '';
    _clarificationReplies = '';
  }
}
