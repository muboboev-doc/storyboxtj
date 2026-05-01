// Phase 1.6: тесты на Auth-методы StoryboxApi (requestOtp, verifyOtp, DTO).
// Backend tests на эндпоинт-стороне; здесь — Dart client тестируется в изоляции.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storybox_app/api/storybox_api.dart';

void main() {
  group('UserStatus enum', () {
    test('parses backend strings', () {
      expect(UserStatus.fromString('active'), UserStatus.active);
      expect(UserStatus.fromString('blocked'), UserStatus.blocked);
      expect(UserStatus.fromString('shadow_banned'), UserStatus.shadowBanned);
      expect(UserStatus.fromString('deleted'), UserStatus.deleted);
    });

    test('toJson roundtrips correctly', () {
      for (final s in UserStatus.values) {
        expect(UserStatus.fromString(s.toJson()), s);
      }
    });

    test('falls back to active on unknown value (defensive)', () {
      expect(UserStatus.fromString('completely_unknown'), UserStatus.active);
    });
  });

  group('User.fromJson', () {
    test('parses full payload from backend', () {
      final user = User.fromJson({
        'id': 1,
        'name': 'Test User',
        'email': null,
        'phone': '+992901234567',
        'locale': 'ru',
        'country_code': 'TJ',
        'referral_code': 'ABC12345',
        'status': 'active',
        'avatar_url': null,
        'email_verified_at': null,
        'created_at': '2026-05-01T10:00:00+00:00',
        'updated_at': '2026-05-01T10:00:00+00:00',
      });

      expect(user.id, 1);
      expect(user.name, 'Test User');
      expect(user.email, isNull);
      expect(user.phone, '+992901234567');
      expect(user.status, UserStatus.active);
      expect(user.locale, 'ru');
      expect(user.countryCode, 'TJ');
      expect(user.referralCode, 'ABC12345');
    });

    test('handles minimal payload (all nullables omitted)', () {
      final user = User.fromJson({
        'id': 2,
        'locale': 'en',
        'status': 'shadow_banned',
        'created_at': '2026-05-01T10:00:00+00:00',
        'updated_at': '2026-05-01T10:00:00+00:00',
      });

      expect(user.id, 2);
      expect(user.name, isNull);
      expect(user.email, isNull);
      expect(user.phone, isNull);
      expect(user.status, UserStatus.shadowBanned);
    });
  });

  group('User.displayName', () {
    test('returns name when present', () {
      final user = _user(name: 'Alice', phone: '+992...');
      expect(user.displayName, 'Alice');
    });

    test('falls back to phone when name missing', () {
      final user = _user(phone: '+992111');
      expect(user.displayName, '+992111');
    });

    test('falls back to email when name+phone missing', () {
      final user = _user(email: 'a@b.com');
      expect(user.displayName, 'a@b.com');
    });

    test('falls back to id when all else null', () {
      final user = _user(id: 42);
      expect(user.displayName, 'User #42');
    });
  });

  group('Wallet.fromJson', () {
    test('parses balances as int', () {
      final wallet = Wallet.fromJson({
        'coins_balance': 100,
        'bonus_coins_balance': 25,
        'total_balance': 125,
      });

      expect(wallet.coinsBalance, 100);
      expect(wallet.bonusCoinsBalance, 25);
      expect(wallet.totalBalance, 125);
    });

    test('handles zero balance', () {
      final wallet = Wallet.fromJson({
        'coins_balance': 0,
        'bonus_coins_balance': 0,
        'total_balance': 0,
      });
      expect(wallet.totalBalance, 0);
    });
  });

  group('RequestOtpResponse.fromJson', () {
    test('parses sent + expires_at', () {
      final r = RequestOtpResponse.fromJson({
        'sent': true,
        'expires_at': '2026-05-01T10:05:00+00:00',
      });
      expect(r.sent, isTrue);
      expect(r.expiresAt.toUtc().year, 2026);
    });
  });

  group('AuthSuccessResponse.fromJson', () {
    test('parses nested user + wallet + token', () {
      final auth = AuthSuccessResponse.fromJson({
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
        'token': '1|abc...',
        'token_type': 'Bearer',
      });

      expect(auth.user.id, 1);
      expect(auth.wallet.coinsBalance, 0);
      expect(auth.token, '1|abc...');
      expect(auth.tokenType, 'Bearer');
    });
  });

  group('StoryboxApi.requestOtp', () {
    late Dio dio;
    late StoryboxApi api;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
      api = StoryboxApi(dio);
    });

    test('returns RequestOtpResponse on 200', () async {
      _mockRoute(dio, '/api/v1/auth/otp/request', 200, {
        'sent': true,
        'expires_at': '2026-05-01T10:05:00+00:00',
      });

      final res = await api.requestOtp(phone: '+992901234567');

      expect(res.sent, isTrue);
      expect(res.expiresAt.year, 2026);
    });

    test('throws ApiError USER_BLOCKED on 422 envelope', () async {
      _mockRoute(dio, '/api/v1/auth/otp/request', 422, {
        'error': {
          'code': 'USER_BLOCKED',
          'message': 'This account is blocked.',
        },
      });

      expect(
        () => api.requestOtp(phone: '+992901234567'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', 'USER_BLOCKED')
              .having((e) => e.statusCode, 'statusCode', 422),
        ),
      );
    });

    test('throws ApiError 429 on rate limit', () async {
      _mockRoute(dio, '/api/v1/auth/otp/request', 429, null);

      expect(
        () => api.requestOtp(phone: '+992901234567'),
        throwsA(
          isA<ApiError>().having((e) => e.statusCode, 'statusCode', 429),
        ),
      );
    });
  });

  group('StoryboxApi.verifyOtp', () {
    late Dio dio;
    late StoryboxApi api;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
      api = StoryboxApi(dio);
    });

    test('returns AuthSuccessResponse on valid code', () async {
      _mockRoute(dio, '/api/v1/auth/otp/verify', 200, {
        'user': {
          'id': 7,
          'phone': '+992901234567',
          'locale': 'ru',
          'status': 'active',
          'created_at': '2026-05-01T10:00:00+00:00',
          'updated_at': '2026-05-01T10:00:00+00:00',
        },
        'wallet': {
          'coins_balance': 100,
          'bonus_coins_balance': 25,
          'total_balance': 125,
        },
        'token': '1|sandbox-token',
        'token_type': 'Bearer',
      });

      final auth = await api.verifyOtp(
        phone: '+992901234567',
        code: '483721',
      );

      expect(auth.user.id, 7);
      expect(auth.user.phone, '+992901234567');
      expect(auth.wallet.totalBalance, 125);
      expect(auth.token, '1|sandbox-token');
    });

    test('throws ApiError INVALID_OTP on wrong code', () async {
      _mockRoute(dio, '/api/v1/auth/otp/verify', 422, {
        'error': {
          'code': 'INVALID_OTP',
          'message': 'OTP is invalid or expired.',
        },
      });

      expect(
        () => api.verifyOtp(phone: '+992901234567', code: '000000'),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'INVALID_OTP'),
        ),
      );
    });

    test('passes referral_code in request body when provided', () async {
      Map<String, dynamic>? capturedBody;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data as Map<String, dynamic>;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'user': {
                    'id': 1,
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
                  'token': '1|x',
                  'token_type': 'Bearer',
                },
              ),
            );
          },
        ),
      );

      await api.verifyOtp(
        phone: '+992901234567',
        code: '123456',
        referralCode: 'ABC12345',
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!['referral_code'], 'ABC12345');
    });

    test('does NOT include referral_code when null', () async {
      Map<String, dynamic>? capturedBody;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data as Map<String, dynamic>;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'user': {
                    'id': 1,
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
                  'token': '1|x',
                  'token_type': 'Bearer',
                },
              ),
            );
          },
        ),
      );

      await api.verifyOtp(phone: '+992901234567', code: '123456');

      expect(capturedBody!.containsKey('referral_code'), isFalse);
    });
  });
}

// ─── Helpers ────────────────────────────────────────────────────────────────

User _user({
  int id = 1,
  String? name,
  String? email,
  String? phone,
  String locale = 'ru',
  UserStatus status = UserStatus.active,
}) {
  return User(
    id: id,
    name: name,
    email: email,
    phone: phone,
    locale: locale,
    status: status,
    createdAt: DateTime.utc(2026, 5),
    updatedAt: DateTime.utc(2026, 5),
  );
}

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
