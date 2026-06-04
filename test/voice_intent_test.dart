import 'package:flutter_test/flutter_test.dart';
import 'package:facebaby_flutter/utils/voice_intent.dart';
import 'package:facebaby_flutter/utils/voice_sleep_action.dart';

void main() {
  test('detects questions in Portuguese', () {
    expect(
      transcriptLooksLikeQuestion(
        'Oi, a minha neném está chorando muito, você sabe o que pode ser?',
      ),
      isTrue,
    );
    expect(
      transcriptLooksLikeQuestion(
        'Olá, tudo bem? Eu queria saber de quanto tempo eu tenho que dar de mamar',
      ),
      isTrue,
    );
    expect(
      transcriptLooksLikeQuestion('Maitê mamou 120 ml de mamadeira agora'),
      isFalse,
    );
    expect(
      transcriptLooksLikeQuestion('coloquei a Maitê para dormir agora'),
      isFalse,
    );
    expect(
      transcriptLooksLikeQuestion('pode ser hora de dormir'),
      isFalse,
    );
  });

  test('normalizeVoiceSleepAction detects start, end, complete', () {
    expect(
      normalizeVoiceSleepAction(
        fromInterpretation: null,
        transcript: 'coloquei para dormir agora',
      ),
      'start',
    );
    expect(
      normalizeVoiceSleepAction(
        fromInterpretation: null,
        transcript: 'a neném acordou',
      ),
      'end',
    );
    expect(
      normalizeVoiceSleepAction(
        fromInterpretation: null,
        transcript: 'dormiu 50 minutos',
      ),
      'complete',
    );
  });

  test('status inquiry does not auto-register', () {
    const inquiry =
        'Oi, como que a Maitê tá hoje? Me fala como ela está agora, '
        'o que eu precisava fazer ou registrar?';
    expect(shouldSkipRoutineAutoRegister(inquiry), isTrue);
    expect(
      interpretationShouldAskAi(type: 'sleep', transcript: inquiry),
      isTrue,
    );
    expect(
      interpretationShouldAskAi(type: 'feeding', transcript: inquiry),
      isTrue,
    );
    expect(
      transcriptLooksLikeQuestion('Maitê mamou 120 ml de mamadeira agora'),
      isFalse,
    );
    expect(
      shouldSkipRoutineAutoRegister('Maitê mamou 120 ml de mamadeira agora'),
      isFalse,
    );
  });

  test('interpretationShouldAskAi routes questions', () {
    expect(
      interpretationShouldAskAi(
        type: 'question',
        transcript: 'qualquer coisa',
      ),
      isTrue,
    );
    expect(
      interpretationShouldAskAi(
        type: 'unknown',
        transcript: 'como faço para aumentar o leite?',
      ),
      isTrue,
    );
    expect(
      interpretationShouldAskAi(
        type: 'feeding',
        transcript: 'mamou 90 ml',
      ),
      isFalse,
    );
  });
}
