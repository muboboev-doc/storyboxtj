/// Безопасное хранилище Sanctum-токена авторизации.
///
/// Использует platform-specific хранилища:
///   - Android — EncryptedSharedPreferences (AES-256)
///   - iOS — Keychain (kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
///   - Web — fallback на window.localStorage (acceptable для Phase 1; в Phase 9
///     anti-piracy включим обфускацию + integrity-проверку)
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Контракт хранилища. Тестируется через мок.
abstract interface class AuthStorage {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> deleteToken();
  Future<bool> hasToken();
}

/// Default impl на flutter_secure_storage.
final class SecureAuthStorage implements AuthStorage {
  SecureAuthStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _kTokenKey = 'sanctum_token';

  @override
  Future<String?> readToken() => _storage.read(key: _kTokenKey);

  @override
  Future<void> writeToken(String token) =>
      _storage.write(key: _kTokenKey, value: token);

  @override
  Future<void> deleteToken() => _storage.delete(key: _kTokenKey);

  @override
  Future<bool> hasToken() => _storage.containsKey(key: _kTokenKey);
}

/// In-memory impl для тестов (не пишет в platform-storage).
final class InMemoryAuthStorage implements AuthStorage {
  String? _token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async => _token = token;

  @override
  Future<void> deleteToken() async => _token = null;

  @override
  Future<bool> hasToken() async => _token != null;
}
