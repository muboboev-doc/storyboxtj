/// Riverpod-провайдеры для auth слоя.
///
/// Top-level:
///   - [authStorageProvider] — Singleton SecureAuthStorage
///   - [storyboxApiProvider] — Dio + AuthInterceptor + StoryboxApi
///   - [authRepositoryProvider] — AuthRepository
///   - [authNotifierProvider] — AuthNotifier (`Notifier<AuthState>`)
///
/// На старте `AuthNotifier.build()` запускает restoreSession() — UI пока в
/// AuthUnknown. После — переходит в Authenticated либо Unauthenticated.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybox_app/api/storybox_api.dart';
import 'package:storybox_app/core/network/auth_interceptor.dart';
import 'package:storybox_app/core/storage/auth_storage.dart';
import 'package:storybox_app/data/auth/auth_repository.dart';
import 'package:storybox_app/flavors.dart';
import 'package:storybox_app/presentation/auth/auth_state.dart';

// ─── Providers ──────────────────────────────────────────────────────────────

final authStorageProvider = Provider<AuthStorage>((ref) {
  return SecureAuthStorage();
});

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(authStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: kAppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(
      storage: storage,
      onUnauthorized: () {
        // Триггерим logout-flow асинхронно (interceptor работает в callback'е).
        unawaited(
          Future.microtask(() {
            ref.read(authNotifierProvider.notifier).handleUnauthorized();
          }),
        );
      },
    ),
  );

  return dio;
});

final storyboxApiProvider = Provider<StoryboxApi>((ref) {
  return StoryboxApi(ref.watch(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(storyboxApiProvider),
    storage: ref.watch(authStorageProvider),
  );
});

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

// ─── Notifier ───────────────────────────────────────────────────────────────

/// Управляет AuthState transitions. UI читает state через `ref.watch`,
/// триггерит изменения через `ref.read(authNotifierProvider.notifier).<method>()`.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Старт: пытаемся восстановить сессию из storage.
    unawaited(Future.microtask(_restoreSession));
    return const AuthUnknown();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _restoreSession() async {
    try {
      final result = await _repo.restoreSession();

      state = switch (result) {
        RestoreSessionSuccess() => Authenticated(
          user: result.user,
          // Wallet ещё не загружен — Phase 3+ добавит fetch /wallet после restore.
          // На Phase 1.7 placeholder с нулями.
          wallet: const Wallet(
            coinsBalance: 0,
            bonusCoinsBalance: 0,
            totalBalance: 0,
          ),
          // Token уже в storage — UI его не использует напрямую, но AuthState
          // инвариант требует. Используем placeholder; реальный токен
          // подставляется через AuthInterceptor.
          token: 'restored',
        ),
        RestoreSessionNoToken() => const Unauthenticated(),
        RestoreSessionTokenExpired() => const Unauthenticated(),
      };
    } on ApiError {
      // Network error на restore — оставляем в Unknown и не разлогиниваем.
      // UI может показать retry-button или auto-retry.
      state = const Unauthenticated();
    }
  }

  /// Шаг 1: пользователь ввёл phone, жмёт «Send code».
  Future<void> requestOtp(String phone) async {
    final previous = state;
    state = RequestingOtp(phone);

    try {
      final response = await _repo.requestOtp(phone: phone);
      state = OtpSent(phone: phone, expiresAt: response.expiresAt);
    } on ApiError catch (e) {
      state = AuthFailed(
        message: e.message,
        errorCode: e.code,
        previous: previous is OtpSent ? previous : const Unauthenticated(),
      );
    }
  }

  /// Шаг 2: пользователь ввёл код, жмёт «Confirm».
  Future<void> verifyOtp({
    required String phone,
    required String code,
    String? referralCode,
  }) async {
    final previous = state;
    state = VerifyingOtp(phone: phone, code: code);

    try {
      final auth = await _repo.verifyOtp(
        phone: phone,
        code: code,
        referralCode: referralCode,
      );
      state = Authenticated(
        user: auth.user,
        wallet: auth.wallet,
        token: auth.token,
      );
    } on ApiError catch (e) {
      // INVALID_OTP — вернуть на экран ввода кода, не разлогинивать.
      // USER_BLOCKED — на стартовый экран.
      final fallback = e.code == 'USER_BLOCKED'
          ? const Unauthenticated()
          : (previous is OtpSent ? previous : const Unauthenticated());

      state = AuthFailed(
        message: e.message,
        errorCode: e.code,
        previous: fallback,
      );
    }
  }

  /// Resend: отправить тот же phone, перетереть OTP в cache.
  Future<void> resendOtp() async {
    final current = state;
    if (current is OtpSent) {
      await requestOtp(current.phone);
    }
  }

  /// «Назад» с экрана ввода кода → ввести phone заново.
  void backToPhoneInput() {
    state = const Unauthenticated();
  }

  /// Dismiss error — вернуться в previous state.
  void dismissError() {
    final current = state;
    if (current is AuthFailed) {
      state = current.previous;
    }
  }

  /// Logout (вручную из profile). Также вызывается из AuthInterceptor при 401.
  Future<void> logout() async {
    await _repo.logout();
    state = const Unauthenticated();
  }

  /// Триггерится из AuthInterceptor при 401. То же что logout, но без
  /// server-side revoke (токен уже невалиден).
  void handleUnauthorized() {
    state = const Unauthenticated();
  }
}
