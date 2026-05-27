import 'package:facebaby_flutter/utils/floating_message_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FloatingMessageAction.httpsUri', () {
    test('accepts https URL', () {
      final uri = FloatingMessageAction.httpsUri('https://facebaby.app/plus');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'facebaby.app');
    });

    test('adds https to host without scheme', () {
      final uri = FloatingMessageAction.httpsUri('www.facebaby.app');
      expect(uri?.toString(), startsWith('https://'));
    });

    test('rejects http and empty host', () {
      expect(FloatingMessageAction.httpsUri('http://example.com'), isNull);
      expect(FloatingMessageAction.httpsUri('https://'), isNull);
      expect(FloatingMessageAction.httpsUri(''), isNull);
    });
  });

  group('FloatingMessageAction.isValidHttpsUrl', () {
    test('matches httpsUri', () {
      expect(
        FloatingMessageAction.isValidHttpsUrl('https://google.com'),
        isTrue,
      );
      expect(FloatingMessageAction.isValidHttpsUrl('ftp://files.example.com'), isFalse);
      expect(FloatingMessageAction.isValidHttpsUrl('://'), isFalse);
    });
  });
}
