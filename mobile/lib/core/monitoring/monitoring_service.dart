/// Monitoring abstraction — Sentry (errors) + Firebase Analytics (events).
///
/// Phase 0.6 — minimal implementation. Phase 1+ extends with custom events
/// (episode_play, unlock_attempt, bank_payment_initiated, etc.).
///
/// Design:
/// - No-op default — приложение работает БЕЗ Sentry/Firebase credentials.
///   Это важно для CI и для разработчиков, которые ещё не получили доступ.
/// - Реальные импл'ы (`SentryMonitoringService`, `FirebaseMonitoringService`)
///   подключаются в `main_<flavor>.dart` через `MonitoringService.init(...)`.
library;

import 'package:flutter/foundation.dart';

/// Контракт для всех monitoring-импл'ов.
///
/// Используется через Riverpod provider в Phase 1+. Для Phase 0.6 это
/// просто синглтон с возможностью init/replace в `main_<flavor>.dart`.
abstract interface class MonitoringService {
  /// Инициализация (Sentry.init / Firebase.initializeApp).
  /// Идемпотентна — безопасно вызывать несколько раз.
  Future<void> initialize();

  /// Лог exception в систему мониторинга.
  /// `extra` — дополнительный контекст (например, route, user_id).
  Future<void> captureException(
    Object exception,
    StackTrace? stackTrace, {
    Map<String, dynamic>? extra,
  });

  /// Лог сообщение (info/warning/error).
  Future<void> captureMessage(
    String message, {
    MonitoringSeverity severity = MonitoringSeverity.info,
    Map<String, dynamic>? extra,
  });

  /// Кастомное analytics-событие (Firebase Analytics).
  /// Имена: `snake_case`, до 40 символов (Firebase ограничение).
  Future<void> trackEvent(
    String name, {
    Map<String, Object>? params,
  });

  /// Установить user-контекст для будущих events.
  /// На logout — `setUser(null)` чтобы очистить.
  Future<void> setUser({String? id, String? email, String? username});

  /// Освободить ресурсы (close clients).
  Future<void> dispose();
}

enum MonitoringSeverity { debug, info, warning, error, fatal }

/// No-op реализация. Используется когда Sentry/Firebase не настроены —
/// приложение функционирует без логирования.
final class NoOpMonitoringService implements MonitoringService {
  NoOpMonitoringService();

  @override
  Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('[Monitoring] NoOp service active — events are dropped.');
    }
  }

  @override
  Future<void> captureException(
    Object exception,
    StackTrace? stackTrace, {
    Map<String, dynamic>? extra,
  }) async {
    if (kDebugMode) {
      debugPrint('[Monitoring][exception] $exception');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }

  @override
  Future<void> captureMessage(
    String message, {
    MonitoringSeverity severity = MonitoringSeverity.info,
    Map<String, dynamic>? extra,
  }) async {
    if (kDebugMode) {
      debugPrint('[Monitoring][${severity.name}] $message');
    }
  }

  @override
  Future<void> trackEvent(String name, {Map<String, Object>? params}) async {
    if (kDebugMode) {
      debugPrint('[Monitoring][event] $name ${params ?? {}}');
    }
  }

  @override
  Future<void> setUser({String? id, String? email, String? username}) async {
    if (kDebugMode) {
      debugPrint('[Monitoring] setUser(id=$id)');
    }
  }

  @override
  Future<void> dispose() async {}
}

/// Глобальный синглтон. Заполняется в `main_<flavor>.dart` ДО `runApp()`.
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   monitoring = NoOpMonitoringService();
///   await monitoring.initialize();
///   runApp(...);
/// }
/// ```
///
/// В Phase 1+ заменим на Riverpod-provider.
MonitoringService monitoring = NoOpMonitoringService();
