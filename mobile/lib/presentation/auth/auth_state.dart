/// State machine для auth flow (Phase 1.7).
///
/// Transitions:
///   Unknown (boot)
///     ├─→ Authenticated (если restoreSession Success)
///     └─→ Unauthenticated
///
///   Unauthenticated
///     ├─→ RequestingOtp(phone)            — пользователь жмёт «Send code»
///         ├─→ OtpSent(phone, expiresAt)   — успешно
///         └─→ Failed(error)               — USER_BLOCKED / network / rate limit
///
///   OtpSent
///     ├─→ VerifyingOtp(phone, code)
///         ├─→ Authenticated(user, ...)
///         └─→ Failed(error)               — INVALID_OTP, ввести снова
///     └─→ RequestingOtp(phone)            — resend
///
///   Authenticated
///     └─→ Unauthenticated                  — logout / 401
library;

import 'package:storybox_app/api/storybox_api.dart';

/// Базовый sealed-класс. Switch exhaustive в UI.
sealed class AuthState {
  const AuthState();
}

/// Начальное — пока приложение пытается восстановить сессию из storage.
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

/// Не залогинен. UI показывает PhoneOtpScreen.
final class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// Идёт запрос OTP. UI блокирует кнопку.
final class RequestingOtp extends AuthState {
  const RequestingOtp(this.phone);
  final String phone;
}

/// OTP отправлен. UI показывает OtpInputScreen.
final class OtpSent extends AuthState {
  const OtpSent({required this.phone, required this.expiresAt});
  final String phone;
  final DateTime expiresAt;
}

/// Идёт verify. UI блокирует кнопку.
final class VerifyingOtp extends AuthState {
  const VerifyingOtp({required this.phone, required this.code});
  final String phone;
  final String code;
}

/// Залогинен. UI показывает HomeScreen.
final class Authenticated extends AuthState {
  const Authenticated({
    required this.user,
    required this.wallet,
    required this.token,
  });
  final User user;
  final Wallet wallet;
  final String token;
}

/// Ошибка. Хранит контекст откуда пришли (чтобы UI знал куда возвращать).
final class AuthFailed extends AuthState {
  const AuthFailed({
    required this.message,
    required this.previous,
    this.errorCode,
  });

  /// Human-readable message (уже локализованное от backend).
  final String message;

  /// Машинно-читаемый код (`USER_BLOCKED`, `INVALID_OTP`, `NETWORK_ERROR`, ...).
  /// Используется для targeted retry: например, `INVALID_OTP` оставляет на
  /// том же экране, `USER_BLOCKED` редиректит на support.
  final String? errorCode;

  /// Состояние, в которое UI должен вернуться при `dismissError()`.
  /// Обычно `Unauthenticated` (для USER_BLOCKED) или `OtpSent` (для INVALID_OTP).
  final AuthState previous;
}
