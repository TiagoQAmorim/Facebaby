import 'package:flutter/foundation.dart';
import 'ai_chat_session.dart';
import 'ai_conversation_state_repository.dart';
import 'ai_nanny_service.dart';
import 'pending_record_session_store.dart';
import 'pending_routine_record_store.dart';

/// Reinicia estado da IA Babá (logout, troca de conta, etc.).
/// Não chamar em `AppLifecycleState.paused` — minimizar não deve apagar o chat.
abstract final class AiSessionReset {
  static bool _resetInFlight = false;

  /// Limpa pendências locais e marca o chat para recomeçar na próxima abertura.
  static Future<void> resetSession({String? welcomeMessage}) async {
    if (_resetInFlight) return;
    _resetInFlight = true;
    try {
      debugPrint('AiSessionReset: explicit session reset');
      AiChatSession.requestFreshChatOnNextOpen();
      PendingRoutineRecordStore.instance.clear();
      await AiConversationStateRepository().clear();
      await PendingRecordSessionStore.instance.clearAllSessions(
        reason: 'app backgrounded',
      );

      final welcome = welcomeMessage?.trim();
      if (welcome != null && welcome.isNotEmpty) {
        final nanny = AiNannyService();
        try {
          nanny.setTyping(false);
          await nanny.resetForNewAppSession(welcome);
        } catch (e) {
          debugPrint('AiSessionReset: chat reset failed $e');
        } finally {
          nanny.dispose();
        }
      }
    } finally {
      _resetInFlight = false;
    }
  }
}
