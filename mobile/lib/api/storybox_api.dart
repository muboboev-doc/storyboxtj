/// Type-safe Dart client для StoryBox API.
///
/// Phase 0.5/1.6 — hand-written минимальная реализация. Контракт совпадает
/// с `docs/openapi.yaml` (источник правды).
///
/// Когда захотим перейти на полноценный openapi-generator — запустится
/// `./scripts/generate-api-client.sh` (требует ASCII project path, см. README).
/// Hand-written клиент будет заменён на сгенерированный без изменений в UI коде —
/// signature методов и DTO остаётся прежней.
library;

import 'package:dio/dio.dart';

// ─── DTO ────────────────────────────────────────────────────────────────────

/// Ответ `GET /api/v1/ping`.
final class PingResponse {
  const PingResponse({
    required this.status,
    required this.service,
    required this.version,
    required this.environment,
    required this.timestamp,
  });

  factory PingResponse.fromJson(Map<String, dynamic> json) {
    return PingResponse(
      status: json['status'] as String,
      service: json['service'] as String,
      version: json['version'] as String,
      environment: json['environment'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  final String status;
  final String service;
  final String version;
  final String environment;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'status': status,
    'service': service,
    'version': version,
    'environment': environment,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() =>
      'PingResponse(status: $status, service: $service, '
      'version: $version, environment: $environment, timestamp: $timestamp)';
}

/// Статус юзера (зеркалит backend `App\Enums\UserStatus`).
enum UserStatus {
  active,
  blocked,
  shadowBanned,
  deleted
  ;

  static UserStatus fromString(String value) => switch (value) {
    'active' => UserStatus.active,
    'blocked' => UserStatus.blocked,
    'shadow_banned' => UserStatus.shadowBanned,
    'deleted' => UserStatus.deleted,
    _ =>
      UserStatus.active, // safe default — не должно случаться при синке backend
  };

  String toJson() => switch (this) {
    UserStatus.active => 'active',
    UserStatus.blocked => 'blocked',
    UserStatus.shadowBanned => 'shadow_banned',
    UserStatus.deleted => 'deleted',
  };
}

/// Ответ `GET /api/v1/me` + поле `user` в `AuthSuccessResponse`.
final class User {
  const User({
    required this.id,
    required this.status,
    required this.locale,
    required this.createdAt,
    required this.updatedAt,
    this.name,
    this.email,
    this.phone,
    this.countryCode,
    this.referralCode,
    this.avatarUrl,
    this.emailVerifiedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      locale: json['locale'] as String,
      countryCode: json['country_code'] as String?,
      referralCode: json['referral_code'] as String?,
      status: UserStatus.fromString(json['status'] as String),
      avatarUrl: json['avatar_url'] as String?,
      emailVerifiedAt: json['email_verified_at'] != null
          ? DateTime.parse(json['email_verified_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final int id;
  final String? name;
  final String? email;
  final String? phone;
  final String locale;
  final String? countryCode;
  final String? referralCode;
  final UserStatus status;
  final String? avatarUrl;
  final DateTime? emailVerifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Display-name для UI: name → phone → email → fallback.
  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    if (phone != null) return phone!;
    if (email != null) return email!;
    return 'User #$id';
  }
}

/// Кошелёк коинов (поле `wallet` в `AuthSuccessResponse`, и в Phase 3+ через `/wallet`).
final class Wallet {
  const Wallet({
    required this.coinsBalance,
    required this.bonusCoinsBalance,
    required this.totalBalance,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      coinsBalance: (json['coins_balance'] as num).toInt(),
      bonusCoinsBalance: (json['bonus_coins_balance'] as num).toInt(),
      totalBalance: (json['total_balance'] as num).toInt(),
    );
  }

  /// Платные коины.
  final int coinsBalance;

  /// Бонусные (рефералы / check-in / реклама).
  final int bonusCoinsBalance;

  /// `coinsBalance + bonusCoinsBalance` (вычисляется на бэке).
  final int totalBalance;
}

/// Ответ `POST /api/v1/auth/otp/request`.
final class RequestOtpResponse {
  const RequestOtpResponse({required this.sent, required this.expiresAt});

  factory RequestOtpResponse.fromJson(Map<String, dynamic> json) {
    return RequestOtpResponse(
      sent: json['sent'] as bool,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  final bool sent;
  final DateTime expiresAt;
}

/// Ответ `POST /api/v1/auth/otp/verify`.
final class AuthSuccessResponse {
  const AuthSuccessResponse({
    required this.user,
    required this.wallet,
    required this.token,
    required this.tokenType,
  });

  factory AuthSuccessResponse.fromJson(Map<String, dynamic> json) {
    return AuthSuccessResponse(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      wallet: Wallet.fromJson(json['wallet'] as Map<String, dynamic>),
      token: json['token'] as String,
      tokenType: json['token_type'] as String,
    );
  }

  final User user;
  final Wallet wallet;

  /// Sanctum personal-access-token. Хранить в secure_storage.
  /// Использовать как `Authorization: Bearer <token>`.
  final String token;

  /// Всегда `'Bearer'`.
  final String tokenType;
}

/// Структурированная ошибка от API (формат `{error:{code, message}}`).
final class ApiError implements Exception {
  const ApiError({required this.code, required this.message, this.statusCode});

  factory ApiError.fromJson(Map<String, dynamic> json, [int? statusCode]) {
    final err = json['error'] as Map<String, dynamic>?;
    return ApiError(
      code: err?['code'] as String? ?? 'UNKNOWN',
      message: err?['message'] as String? ?? 'Unknown error',
      statusCode: statusCode,
    );
  }

  /// Известные коды:
  /// - `UNAUTHENTICATED`
  /// - `INVALID_OTP`
  /// - `USER_BLOCKED`
  /// - `NETWORK_ERROR` (клиентский — нет ответа от сервера)
  final String code;

  /// Human-readable, локализованное по `Accept-Language`.
  final String message;

  /// HTTP status code (если применимо).
  final int? statusCode;

  @override
  String toString() =>
      'ApiError($code${statusCode != null ? ' [$statusCode]' : ''}: $message)';
}

// ─── Client ─────────────────────────────────────────────────────────────────

/// Клиент StoryBox API. Один экземпляр на приложение.
///
/// ```dart
/// final client = StoryboxApi(Dio(BaseOptions(baseUrl: 'http://localhost:8080')));
/// final ping = await client.ping();
/// final r = await client.requestOtp(phone: '+992901234567');
/// final auth = await client.verifyOtp(phone: '+992901234567', code: '483721');
/// final me = await client.getCurrentUser(); // нужен interceptor с Bearer auth.token
/// ```
final class StoryboxApi {
  StoryboxApi(this._dio);

  final Dio _dio;

  // ─── System ───────────────────────────────────────────────────────────────

  /// `GET /api/v1/ping` — health check, без авторизации.
  Future<PingResponse> ping() async {
    final res = await _request<Map<String, dynamic>>(
      method: 'GET',
      path: '/api/v1/ping',
    );
    return PingResponse.fromJson(res);
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  /// `POST /api/v1/auth/otp/request` — отправить OTP на phone.
  ///
  /// Throws [ApiError] с кодом:
  /// - `USER_BLOCKED` — phone привязан к заблокированному юзеру
  /// - validation errors → 422 (ApiError.code='UNKNOWN' с deatails в message)
  /// - Rate limit → ApiError.statusCode=429
  Future<RequestOtpResponse> requestOtp({required String phone}) async {
    final res = await _request<Map<String, dynamic>>(
      method: 'POST',
      path: '/api/v1/auth/otp/request',
      data: {'phone': phone},
    );
    return RequestOtpResponse.fromJson(res);
  }

  /// `POST /api/v1/auth/otp/verify` — проверить код, получить Sanctum token.
  ///
  /// При успехе возвращает [AuthSuccessResponse] с user, wallet и токеном.
  /// Сохраните `auth.token` в secure_storage и используйте для последующих
  /// запросов.
  ///
  /// Throws [ApiError]:
  /// - `INVALID_OTP` — код не найден / не совпал / истёк
  /// - `USER_BLOCKED` — defense-in-depth (между request и verify)
  Future<AuthSuccessResponse> verifyOtp({
    required String phone,
    required String code,
    String? referralCode,
  }) async {
    final body = <String, dynamic>{
      'phone': phone,
      'code': code,
      // ignore: use_null_aware_elements (older syntax — null-aware key not stable yet)
      if (referralCode != null) 'referral_code': referralCode,
    };

    final res = await _request<Map<String, dynamic>>(
      method: 'POST',
      path: '/api/v1/auth/otp/verify',
      data: body,
    );
    return AuthSuccessResponse.fromJson(res);
  }

  // ─── User ─────────────────────────────────────────────────────────────────

  /// `GET /api/v1/me` — текущий авторизованный пользователь.
  /// Требует Sanctum-токен в `Authorization: Bearer ...`.
  /// Бросит [ApiError] с кодом `UNAUTHENTICATED` если токена нет/протух.
  Future<User> getCurrentUser() async {
    final res = await _request<Map<String, dynamic>>(
      method: 'GET',
      path: '/api/v1/me',
    );
    return User.fromJson(res);
  }

  // ─── Internal ─────────────────────────────────────────────────────────────

  /// Транспорт. Маппит DioException на ApiError для удобства вызывающего.
  Future<T> _request<T>({
    required String method,
    required String path,
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.request<T>(
        path,
        options: Options(
          method: method,
          headers: {'Accept': 'application/json'},
        ),
        data: data,
        queryParameters: queryParameters,
      );
      return response.data as T;
    } on DioException catch (e) {
      if (e.response?.data is Map<String, dynamic>) {
        throw ApiError.fromJson(
          e.response!.data as Map<String, dynamic>,
          e.response?.statusCode,
        );
      }
      throw ApiError(
        code: 'NETWORK_ERROR',
        message: e.message ?? 'Connection failed',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
