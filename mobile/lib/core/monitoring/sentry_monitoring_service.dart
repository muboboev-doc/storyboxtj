import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:storybox_app/core/monitoring/monitoring_service.dart';

/// Sentry-реализация MonitoringService.
///
/// `dsn` пустой → SDK auto-disabled (graceful no-op, как у `NoOpMonitoringService`,
/// но с публикуемым flag в Sentry для верификации в Phase 1+).
final class SentryMonitoringService implements MonitoringService {
  SentryMonitoringService({
    required this.dsn,
    required this.environment,
    this.release,
    this.tracesSampleRate = 1.0,
    this.sendDefaultPii = false,
  });

  final String dsn;
  final String environment;
  final String? release;
  final double tracesSampleRate;
  final bool sendDefaultPii;

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    // Если DSN пустой — пропускаем init. SDK всё равно бы no-op,
    // но мы избегаем bootstrap-warnings в logs.
    if (dsn.isEmpty) return;

    await SentryFlutter.init((options) {
      options
        ..dsn = dsn
        ..environment = environment
        ..tracesSampleRate = tracesSampleRate
        ..sendDefaultPii = sendDefaultPii
        ..attachStacktrace = true
        ..debug = false;

      if (release != null && release!.isNotEmpty) {
        options.release = release;
      }
    });

    _initialized = true;
  }

  @override
  Future<void> captureException(
    Object exception,
    StackTrace? stackTrace, {
    Map<String, dynamic>? extra,
  }) async {
    if (!_initialized) return;

    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: extra == null
          ? null
          : (scope) => scope.setContexts('extra', extra),
    );
  }

  @override
  Future<void> captureMessage(
    String message, {
    MonitoringSeverity severity = MonitoringSeverity.info,
    Map<String, dynamic>? extra,
  }) async {
    if (!_initialized) return;

    await Sentry.captureMessage(
      message,
      level: _mapSeverity(severity),
      withScope: extra == null
          ? null
          : (scope) => scope.setContexts('extra', extra),
    );
  }

  /// Sentry не имеет встроенных analytics events — для трекинга используем
  /// breadcrumbs (видны вокруг следующего exception). Реальный analytics —
  /// в FirebaseMonitoringService (добавится в Phase 1+).
  @override
  Future<void> trackEvent(String name, {Map<String, Object>? params}) async {
    if (!_initialized) return;

    await Sentry.addBreadcrumb(
      Breadcrumb(
        message: name,
        category: 'event',
        data: params,
        level: SentryLevel.info,
      ),
    );
  }

  @override
  Future<void> setUser({String? id, String? email, String? username}) async {
    if (!_initialized) return;

    final user = (id == null && email == null && username == null)
        ? null
        : SentryUser(id: id, email: email, username: username);

    Sentry.configureScope((scope) => scope.setUser(user));
  }

  @override
  Future<void> dispose() async {
    if (_initialized) {
      await Sentry.close();
      _initialized = false;
    }
  }

  SentryLevel _mapSeverity(MonitoringSeverity s) => switch (s) {
    MonitoringSeverity.debug => SentryLevel.debug,
    MonitoringSeverity.info => SentryLevel.info,
    MonitoringSeverity.warning => SentryLevel.warning,
    MonitoringSeverity.error => SentryLevel.error,
    MonitoringSeverity.fatal => SentryLevel.fatal,
  };
}
