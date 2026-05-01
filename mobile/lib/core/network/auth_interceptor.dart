/// Dio-интерсептор: добавляет `Authorization: Bearer <token>` ко всем запросам,
/// если токен есть в [AuthStorage]. Очищает токен при 401 (token истёк или
/// был отозван — backend возвращает 401, мы триггерим logout-flow).
library;

import 'package:dio/dio.dart';

import 'package:storybox_app/core/storage/auth_storage.dart';

/// Callback который вызовется когда interceptor получит 401 от backend.
/// AuthNotifier подпишется и сделает state = Unauthenticated.
typedef OnUnauthorized = void Function();

final class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required AuthStorage storage,
    OnUnauthorized? onUnauthorized,
  }) : _storage = storage,
       _onUnauthorized = onUnauthorized;

  final AuthStorage _storage;
  final OnUnauthorized? _onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip публичные endpoints (request/verify сами выдают токен).
    if (_isAuthEndpoint(options.path)) {
      return handler.next(options);
    }

    final token = await _storage.readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // Token невалиден — чистим storage и уведомляем AuthNotifier.
      await _storage.deleteToken();
      _onUnauthorized?.call();
    }
    handler.next(err);
  }

  bool _isAuthEndpoint(String path) {
    return path.contains('/auth/otp/request') ||
        path.contains('/auth/otp/verify') ||
        path.contains('/ping');
  }
}
