/// Высокоуровневая обёртка над [StoryboxApi] + [AuthStorage].
///
/// Отвечает за persistence Sanctum-токена и за derivation auth-state из storage.
/// AuthNotifier (Riverpod) использует этот repository как единственную
/// точку правды для login/logout/restore.
library;

import 'package:storybox_app/api/storybox_api.dart';
import 'package:storybox_app/core/storage/auth_storage.dart';

/// Результат restore-session попытки на старте приложения.
sealed class RestoreSessionResult {
  const RestoreSessionResult();
}

/// Токен есть в storage и /me ответил OK.
final class RestoreSessionSuccess extends RestoreSessionResult {
  const RestoreSessionSuccess(this.user);
  final User user;
}

/// Токена нет в storage.
final class RestoreSessionNoToken extends RestoreSessionResult {
  const RestoreSessionNoToken();
}

/// Токен есть, но /me вернул 401 — токен протух/отозван. Storage очищен.
final class RestoreSessionTokenExpired extends RestoreSessionResult {
  const RestoreSessionTokenExpired();
}

final class AuthRepository {
  AuthRepository({required StoryboxApi api, required AuthStorage storage})
    : _api = api,
      _storage = storage;

  final StoryboxApi _api;
  final AuthStorage _storage;

  /// Запросить OTP — backend стороной отправит код на phone через Telegram.
  Future<RequestOtpResponse> requestOtp({required String phone}) {
    return _api.requestOtp(phone: phone);
  }

  /// Проверить OTP, сохранить токен в storage, вернуть auth payload.
  ///
  /// [referralCode] применяется только при создании НОВОГО юзера. Невалидный код
  /// silent-ignored бэкендом.
  Future<AuthSuccessResponse> verifyOtp({
    required String phone,
    required String code,
    String? referralCode,
  }) async {
    final auth = await _api.verifyOtp(
      phone: phone,
      code: code,
      referralCode: referralCode,
    );
    await _storage.writeToken(auth.token);
    return auth;
  }

  /// Logout: очищает storage. Server-side revoke (через `Sanctum::tokens()->delete()`)
  /// будет добавлен в Phase 1.8+.
  Future<void> logout() async {
    await _storage.deleteToken();
  }

  /// На старте приложения — попробовать восстановить сессию.
  /// Если токен есть и /me работает — возвращаем User; иначе — соответствующий
  /// результат (см. [RestoreSessionResult]).
  Future<RestoreSessionResult> restoreSession() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      return const RestoreSessionNoToken();
    }

    try {
      final user = await _api.getCurrentUser();
      return RestoreSessionSuccess(user);
    } on ApiError catch (e) {
      if (e.statusCode == 401) {
        await _storage.deleteToken();
        return const RestoreSessionTokenExpired();
      }
      // Network error / 500 — не разлогиниваем, оставляем токен.
      // Дать юзеру retry; в worst case он снова залогинится.
      rethrow;
    }
  }
}
