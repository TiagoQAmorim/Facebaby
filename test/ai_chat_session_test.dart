import 'package:facebaby_flutter/services/ai/ai_chat_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requestFreshChatOnNextOpen força novo chat após marcar preparado', () {
    AiChatSession.onAppStarted();
    expect(AiChatSession.needsFreshChatOnOpen, isTrue);
    AiChatSession.markChatPreparedForLaunch();
    expect(AiChatSession.needsFreshChatOnOpen, isFalse);
    AiChatSession.requestFreshChatOnNextOpen();
    expect(AiChatSession.needsFreshChatOnOpen, isTrue);
  });
}
