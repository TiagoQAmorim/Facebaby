import 'package:facebaby_flutter/services/ai/ai_bubble_queue_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiBubbleQueueLifecycle', () {
    test('expira mensagem não vista após 3 dias', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const babyId = 1;
      const prefsKey = 'daily';

      await AiBubbleQueueLifecycle.ensureAnchorDay(babyId: babyId, prefs: prefs);
      await prefs.setString(
        'facebaby_bubble_enq_${babyId}_$prefsKey',
        DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
      );

      final show = await AiBubbleQueueLifecycle.shouldShow(
        babyId: babyId,
        prefsKey: prefsKey,
        prefs: prefs,
        contentDay: DateTime.now(),
      );
      expect(show, isFalse);
    });

    test('bloqueia conteúdo de dia anterior ao anchor', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const babyId = 2;
      const prefsKey = 'yesterday_curiosity_brief';

      final anchor = await AiBubbleQueueLifecycle.ensureAnchorDay(
        babyId: babyId,
        prefs: prefs,
      );
      await AiBubbleQueueLifecycle.noteEnqueued(
        babyId: babyId,
        prefsKey: prefsKey,
        prefs: prefs,
      );

      final show = await AiBubbleQueueLifecycle.shouldShow(
        babyId: babyId,
        prefsKey: prefsKey,
        prefs: prefs,
        contentDay: anchor.subtract(const Duration(days: 1)),
      );
      expect(show, isFalse);
    });

    test('admin persiste até fechar mesmo após 3 dias sem abrir', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const babyId = 4;
      const prefsKey = 'admin_campaign_xyz';

      await prefs.setString(
        'facebaby_bubble_enq_${babyId}_$prefsKey',
        DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
      );

      final show = await AiBubbleQueueLifecycle.shouldShow(
        babyId: babyId,
        prefsKey: prefsKey,
        prefs: prefs,
        persistUntilDismissed: true,
      );
      expect(show, isTrue);
    });

    test('dispensar é permanente', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const babyId = 3;
      const prefsKey = 'weekly';

      await AiBubbleQueueLifecycle.markDismissed(
        babyId: babyId,
        prefsKey: prefsKey,
        prefs: prefs,
      );

      final show = await AiBubbleQueueLifecycle.shouldShow(
        babyId: babyId,
        prefsKey: prefsKey,
        prefs: prefs,
        contentDay: DateTime.now(),
      );
      expect(show, isFalse);
    });
  });
}
