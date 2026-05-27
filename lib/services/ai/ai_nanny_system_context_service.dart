import '../../controllers/breastfeeding_timer_controller.dart';
import '../../controllers/current_baby_controller.dart';
import '../../controllers/sleep_timer_controller.dart';
import '../../models/ai/ai_nanny_system_context.dart';
import 'pending_record_session_store.dart';

/// Consulta timers e sessões ativas — lógica do app, não da IA.
abstract final class AiNannySystemContextService {
  static Future<AiNannySystemContext> load({int? babyId}) async {
    final bid = babyId ?? CurrentBabyController.instance.currentBabyId;

    await SleepTimerController.instance.init();

    ActiveSleepSessionInfo? sleep;
    final st = SleepTimerController.instance;
    if (st.isTracking && st.babyId != null && st.startedAt != null) {
      if (bid == null || st.babyId == bid) {
        final elapsed = st.effectiveElapsed;
        final mins = elapsed.inMinutes.clamp(1, 24 * 60);
        sleep = ActiveSleepSessionInfo(
          babyId: st.babyId!,
          startedAt: st.startedAt!,
          durationMinutes: mins,
          durationSec: elapsed.inSeconds,
          isPaused: st.isPaused,
        );
      }
    }

    ActiveBreastfeedingSessionInfo? breast;
    final bt = BreastfeedingTimerController.instance;
    if (bt.isRunning && bt.babyId != null && bt.startedAt != null && bt.side != null) {
      if (bid == null || bt.babyId == bid) {
        final elapsed = bt.elapsedForSide(bt.side!);
        breast = ActiveBreastfeedingSessionInfo(
          babyId: bt.babyId!,
          side: bt.side!,
          startedAt: bt.startedAt!,
          durationMinutes: elapsed.inMinutes.clamp(1, 180),
        );
      }
    }

    var hasPending = false;
    if (bid != null) {
      await PendingRecordSessionStore.instance.loadForBaby(bid);
      hasPending = PendingRecordSessionStore.instance.blocksGenericChat(bid);
    }

    return AiNannySystemContext(
      babyId: bid,
      activeSleep: sleep,
      activeBreastfeeding: breast,
      hasPendingRecordSession: hasPending,
    );
  }
}
