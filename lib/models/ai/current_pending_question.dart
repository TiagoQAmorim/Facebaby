import 'detected_baby_record.dart';

/// Pergunta pendente explícita — o utilizador nunca deve adivinhar o que responder.
class CurrentPendingQuestion {
  const CurrentPendingQuestion({
    required this.recordType,
    required this.field,
    required this.question,
    this.options = const [],
    this.inputType = AiFollowUpInputType.choice,
    required this.recordIndex,
  });

  final String recordType;
  final String field;
  final String question;
  final List<String> options;
  final AiFollowUpInputType inputType;
  final int recordIndex;

  factory CurrentPendingQuestion.fromFollowUp(AiFollowUpQuestion q) {
    return CurrentPendingQuestion(
      recordType: q.recordType,
      field: q.field,
      question: q.question,
      options: q.options,
      inputType: q.inputType,
      recordIndex: q.recordIndex,
    );
  }

  AiFollowUpQuestion toFollowUp() => AiFollowUpQuestion(
        recordIndex: recordIndex,
        recordType: recordType,
        field: field,
        question: question,
        options: options,
        inputType: inputType,
      );
}
