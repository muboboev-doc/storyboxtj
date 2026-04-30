/// Type-safe Dart client для StoryBox API.
///
/// Phase 0.5 — hand-written минимальная реализация. Контракт совпадает
/// с `docs/openapi.yaml` (одна источник правды).
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

  /// Всегда `'ok'`. Если endpoint вернул что-то ещё — это баг бэка.
  final String status;

  /// Имя сервиса (`StoryBox`).
  final String service;

  /// Backend semver (`0.0.1`).
  final String version;

  /// `local` / `testing` / `staging` / `production`.
  final String environment;

  /// Время сервера в момент ответа.
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

/// Ответ `GET /api/v1/me` (авторизованный пользователь).
final class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
    this.emailVerifiedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      email: json['email'] as String,
      emailVerifiedAt: json['email_verified_at'] != null
          ? DateTime.parse(json['email_verified_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final int id;
  final String name;
  final String email;
  final DateTime? emailVerifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
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

  /// Stable машинно-читаемый код (`UNAUTHENTICATED`, `INSUFFICIENT_COINS`, ...).
  final String code;

  /// Human-readable сообщение, локализованное по `Accept-Language`.
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
/// ```
final class StoryboxApi {
  StoryboxApi(this._dio);

  final Dio _dio;

  /// `GET /api/v1/ping` — health check, без авторизации.
  Future<PingResponse> ping() async {
    final res = await _request<Map<String, dynamic>>(
      method: 'GET',
      path: '/api/v1/ping',
    );
    return PingResponse.fromJson(res);
  }

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

  /// Внутренний транспорт. Маппит DioException на ApiError для удобства
  /// вызывающего кода.
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
