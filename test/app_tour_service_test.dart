import 'package:facebaby_flutter/services/app_tour/app_tour_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('local completion flag persists', () async {
    final svc = AppTourService.instance;
    expect(await svc.isCompletedLocally(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('facebaby_app_tour_completed_v1', true);
    expect(await svc.isCompletedLocally(), isTrue);
  });
}
