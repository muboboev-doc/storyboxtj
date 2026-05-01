// Phase 0.5: unit-тесты type-safe API клиента.
// Контракт совпадает с docs/openapi.yaml. Когда переедем на openapi-generator —
// эти тесты должны продолжать проходить (DTO и сигнатуры неизменны).

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storybox_app/api/storybox_api.dart';

void main() {
  group('PingResponse.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'status': 'ok',
        'service': 'StoryBox',
        'version': '0.0.1',
        'environment': 'local',
        'timestamp': '2026-04-30T12:34:56+00:00',
      };

      final response = PingResponse.fromJson(json);

      expect(response.status, 'ok');
      expect(response.service, 'StoryBox');
      expect(response.version, '0.0.1');
      expect(response.environment, 'local');
      expect(
        response.timestamp.toUtc().toIso8601String(),
        '2026-04-30T12:34:56.000Z',
      );
    });

    test('roundtrip via toJson preserves data', () {
      final original = PingResponse(
        status: 'ok',
        service: 'StoryBox',
        version: '0.0.1',
        environment: 'testing',
        timestamp: DateTime.utc(2026, 4, 30, 12),
      );

      final clone = PingResponse.fromJson(original.toJson());

      expect(clone.status, original.status);
      expect(clone.service, original.service);
      expect(clone.version, original.version);
      expect(clone.environment, original.environment);
      expect(clone.timestamp, original.timestamp);
    });
  });

  group('User.fromJson — basic compatibility (Phase 0.5 contract)', () {
    // Эти тесты были написаны в Phase 0.5 когда User имел упрощённую schema.
    // В Phase 1.6 schema расширилась обязательными полями (locale, status).
    // Тесты обновлены под новый контракт; полные тесты теперь в auth_api_test.dart.

    test('parses payload with email_verified_at', () {
      final user = User.fromJson({
        'id': 1,
        'name': 'Super Admin',
        'email': 'admin@storybox.tj',
        'locale': 'ru',
        'status': 'active',
        'email_verified_at': '2026-04-30T10:00:00+00:00',
        'created_at': '2026-04-29T10:00:00+00:00',
        'updated_at': '2026-04-30T10:00:00+00:00',
      });

      expect(user.id, 1);
      expect(user.name, 'Super Admin');
      expect(user.email, 'admin@storybox.tj');
      expect(user.emailVerifiedAt, isNotNull);
      expect(user.createdAt.toUtc().year, 2026);
    });

    test('handles null email_verified_at', () {
      expect(
        User.fromJson({
          'id': 2,
          'name': 'Unverified',
          'email': 'pending@storybox.tj',
          'locale': 'ru',
          'status': 'active',
          'email_verified_at': null,
          'created_at': '2026-04-30T10:00:00+00:00',
          'updated_at': '2026-04-30T10:00:00+00:00',
        }).emailVerifiedAt,
        isNull,
      );
    });
  });

  group('ApiError.fromJson', () {
    test('parses error envelope', () {
      final error = ApiError.fromJson({
        'error': {
          'code': 'UNAUTHENTICATED',
          'message': 'Token missing or invalid',
        },
      }, 401);

      expect(error.code, 'UNAUTHENTICATED');
      expect(error.message, 'Token missing or invalid');
      expect(error.statusCode, 401);
    });

    test('falls back to UNKNOWN if envelope missing', () {
      final error = ApiError.fromJson({});
      expect(error.code, 'UNKNOWN');
    });

    test('toString includes status code when present', () {
      const error = ApiError(
        code: 'INSUFFICIENT_COINS',
        message: 'Need 50',
        statusCode: 402,
      );
      expect(error.toString(), contains('402'));
      expect(error.toString(), contains('INSUFFICIENT_COINS'));
    });
  });

  group('StoryboxApi.ping', () {
    late Dio dio;
    late StoryboxApi api;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
      api = StoryboxApi(dio);
    });

    test('returns parsed PingResponse on 200', () async {
      // Используем DioAdapter фабрики через interceptor для мокинга.
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/v1/ping') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'status': 'ok',
                    'service': 'StoryBox',
                    'version': '0.0.1',
                    'environment': 'testing',
                    'timestamp': '2026-04-30T12:00:00+00:00',
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final response = await api.ping();

      expect(response.status, 'ok');
      expect(response.environment, 'testing');
    });

    test('throws ApiError on network failure', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                message: 'Connection refused',
              ),
            );
          },
        ),
      );

      expect(
        () => api.ping(),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', 'NETWORK_ERROR')
              .having(
                (e) => e.message,
                'message',
                contains('Connection refused'),
              ),
        ),
      );
    });

    test('throws structured ApiError on server error envelope', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 401,
                  data: {
                    'error': {
                      'code': 'UNAUTHENTICATED',
                      'message': 'Token missing',
                    },
                  },
                ),
              ),
            );
          },
        ),
      );

      expect(
        () => api.getCurrentUser(),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', 'UNAUTHENTICATED')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });
}
