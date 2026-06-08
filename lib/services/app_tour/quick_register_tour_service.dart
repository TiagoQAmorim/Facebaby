import 'package:shared_preferences/shared_preferences.dart';

/// First-time coach marks on the Registos (quick register) tab.
class QuickRegisterTourService {
  QuickRegisterTourService._();

  static final QuickRegisterTourService instance = QuickRegisterTourService._();

  static const _prefCompleted = 'facebaby_quick_register_tour_completed_v1';

  Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefCompleted) ?? false);
  }

  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefCompleted, true);
  }
}
