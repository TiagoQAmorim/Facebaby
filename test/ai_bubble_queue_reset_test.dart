import 'package:facebaby_flutter/models/bubble_queue_settings.dart';
import 'package:facebaby_flutter/services/ai/ai_bubble_queue_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('runGlobalResetIfNeeded purges local bubble keys on generation bump',
      () async {
    SharedPreferences.setMockInitialValues({
      'facebaby_bubble_queue_gen_v1': 0,
      'facebaby_bubble_enq_1_daily': DateTime.now().toIso8601String(),
      'facebaby_bubble_seen_1_weekly': true,
      'facebaby_bubble_dismiss_1_admin_x': true,
      'facebaby_bubble_anchor_v1_1': DateTime.now().toIso8601String(),
      'facebaby_ai_bubble_pos_v1_1_dx': 12.0,
    });
    final prefs = await SharedPreferences.getInstance();

    await AiBubbleQueueLifecycle.runGlobalResetIfNeeded(
      prefs: prefs,
      settings: const BubbleQueueSettings(localQueueGeneration: 2),
    );

    expect(prefs.getInt('facebaby_bubble_queue_gen_v1'), 2);
    expect(prefs.containsKey('facebaby_bubble_enq_1_daily'), isFalse);
    expect(prefs.containsKey('facebaby_bubble_anchor_v1_1'), isFalse);
    expect(prefs.getDouble('facebaby_ai_bubble_pos_v1_1_dx'), 12.0);
  });
}
