// Phase 1.7: тесты на AuthRepository.
// StoryboxApi мокается через подмену Dio interceptor'ов.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storybox_app/api/storybox_api.dart';
import 'package:storybox_app/core/storage/auth_storage.dart';
import 'package:storybox_app/data/auth/auth_repository.dart';

void main() {
  late Dio dio;
  late StoryboxApi api;
  late InMemoryAuthStorage storage;
  late AuthRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    api = StoryboxApi(dio);
    storage = InMemoryAuthStorage();
    repo = AuthRepository(api: api, storage: storage);
  });

  group('verifyOtp', () {
    test('persists token to storage on success', () async {
      _mockRoute(dio, '/api/v1/auth/otp/verify', 200, _validAuthPayload());

      final result = await repo.verifyOtp(
        phone: '+992901234567',
        code: '123456',
      );

      expect(result.token, '1|test-token');
      expect(await storage.readToken(), '1|test-token');
    });

    test('does not persist token on failure', () async {
      _mockRoute(dio, '/api/v1/auth/otp/verify', 422, {
        'error': {'code': 'INVALID_OTP', 'message': 'OTP is invalid.'},
      });

      try {
        await repo.verifyOtp(phone: '+992901234567', code: '000000');
        fail('Should have thrown');
      } on ApiError {
        // expected
      }

      expect(await storage.readToken(), isNull);
    });
  });

  group('logout', () {
    test('clears storage', () async {
      await storage.writeToken('1|abc');
      await repo.logout();
      expect(await storage.readToken(), isNull);
    });
  });

  group('restoreSession', () {
    test('returns NoToken when storage empty', () async {
      final result = await repo.restoreSession();
      expect(result, isA<RestoreSessionNoToken>());
    });

    test('returns Success when /me returns user', () async {
      await storage.writeToken('1|valid');
      _mockRoute(dio, '/api/v1/me', 200, {
        'id': 1,
        'phone': '+992901234567',
        'locale': 'ru',
        'status': 'active',
        'created_at': '2026-05-01T10:00:00+00:00',
        'updated_at': '2026-05-01T10:00:00+00:00',
      });

      final result = await repo.restoreSession();

      expect(result, isA<RestoreSessionSuccess>());
      expect((result as RestoreSessionSuccess).user.id, 1);
    });

    test('returns TokenExpired and clears storage on 401', () async {
      await storage.writeToken('1|expired');
      _mockRoute(dio, '/api/v1/me', 401, {
        'error': {'code': 'UNAUTHENTICATED', 'message': 'Token invalid.'},
      });

      final result = await repo.restoreSession();

      expect(result, isA<RestoreSessionTokenExpired>());
      expect(await storage.readToken(), isNull);
    });

    test('rethrows on non-401 errors (preserves token)', () async {
      await storage.writeToken('1|valid');
      _mockRoute(dio, '/api/v1/me', 500, {
        'error': {'code': 'INTERNAL', 'message': 'Server error.'},
      });

      try {
        await repo.restoreSession();
        fail('Should have thrown');
      } on ApiError catch (e) {
        expect(e.statusCode, 500);
      }

      expect(await storage.readToken(), '1|valid');
    });
  });
}

// ─── Helpers ────────────────────────────────────────────────────────────────

Map<String, dynamic> _validAuthPayload() => {
  'user': {
    'id': 1,
    'phone': '+992901234567',
    'locale': 'ru',
    'status': 'active',
    'created_at': '2026-05-01T10:00:00+00:00',
    'updated_at': '2026-05-01T10:00:00+00:00',
  },
  'wallet': {
    'coins_balance': 0,
    'bonus_coins_balance': 0,
    'total_balance': 0,
  },
  'token': '1|test-token',
  'token_type': 'Bearer',
};

void _mockRoute(
  Dio dio,
  String path,
  int statusCode,
  Map<String, dynamic>? body,
) {
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path != path) {
          return handler.next(options);
        }
        if (statusCode >= 200 && statusCode < 300) {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: statusCode,
              data: body,
            ),
          );
        }
        return handler.reject(
          DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: statusCode,
              data: body,
            ),
          ),
        );
      },
    ),
  );
}
