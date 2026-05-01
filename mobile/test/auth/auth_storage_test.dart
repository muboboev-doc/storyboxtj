// Phase 1.7: тесты на AuthStorage abstraction.
// SecureAuthStorage не тестируется здесь — он требует platform plugins.
// InMemoryAuthStorage используется в widget/integration тестах.

import 'package:flutter_test/flutter_test.dart';
import 'package:storybox_app/core/storage/auth_storage.dart';

void main() {
  group('InMemoryAuthStorage', () {
    late InMemoryAuthStorage storage;

    setUp(() {
      storage = InMemoryAuthStorage();
    });

    test('readToken returns null when empty', () async {
      expect(await storage.readToken(), isNull);
      expect(await storage.hasToken(), isFalse);
    });

    test('writeToken persists value', () async {
      await storage.writeToken('1|abc');
      expect(await storage.readToken(), '1|abc');
      expect(await storage.hasToken(), isTrue);
    });

    test('deleteToken clears value', () async {
      await storage.writeToken('1|abc');
      await storage.deleteToken();
      expect(await storage.readToken(), isNull);
      expect(await storage.hasToken(), isFalse);
    });

    test('overwrites existing token', () async {
      await storage.writeToken('1|first');
      await storage.writeToken('2|second');
      expect(await storage.readToken(), '2|second');
    });
  });
}
