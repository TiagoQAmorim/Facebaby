import 'package:facebaby_flutter/services/firebase/auth_session_restore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('hadPriorSession is false when empty', () async {
    expect(await AuthSessionRestore.hadPriorSession(), isFalse);
  });

  test('hadPriorSession is true when uid stored', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('facebaby_last_auth_uid_v1', 'uid-abc');
    expect(await AuthSessionRestore.hadPriorSession(), isTrue);
  });

  test('clear removes uid hint', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('facebaby_last_auth_uid_v1', 'uid-abc');
    await AuthSessionRestore.clear();
    expect(await AuthSessionRestore.hadPriorSession(), isFalse);
  });
}
