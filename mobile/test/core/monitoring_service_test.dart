// Phase 0.6: tests for monitoring abstraction.
// Реальные Sentry-импл'ы тестируются через mocking SentryFlutter — на baseline
// проверяем только NoOp + контракт.

import 'package:flutter_test/flutter_test.dart';
import 'package:storybox_app/core/monitoring/monitoring_service.dart';

void main() {
  group('NoOpMonitoringService', () {
    late NoOpMonitoringService service;

    setUp(() {
      service = NoOpMonitoringService();
    });

    test('initialize is no-op and never throws', () async {
      await expectLater(service.initialize(), completes);
    });

    test('captureException with stack trace does not throw', () async {
      await expectLater(
        service.captureException(
          Exception('test'),
          StackTrace.current,
          extra: {'key': 'value'},
        ),
        completes,
      );
    });

    test('captureException with null stack does not throw', () async {
      await expectLater(
        service.captureException(Exception('test'), null),
        completes,
      );
    });

    test('captureMessage at all severities does not throw', () async {
      for (final s in MonitoringSeverity.values) {
        await expectLater(
          service.captureMessage('msg', severity: s),
          completes,
        );
      }
    });

    test('trackEvent with params does not throw', () async {
      await expectLater(
        service.trackEvent('episode_play', params: {'episode_id': 42}),
        completes,
      );
    });

    test('setUser and clear (null params) do not throw', () async {
      await expectLater(
        service.setUser(id: '1', email: 'a@b.com'),
        completes,
      );
      await expectLater(service.setUser(), completes);
    });

    test('dispose is no-op and never throws', () async {
      await expectLater(service.dispose(), completes);
    });
  });

  group('global monitoring singleton', () {
    test('default is NoOp', () {
      expect(monitoring, isA<NoOpMonitoringService>());
    });

    test('global singleton can be reassigned (used by main_<flavor>.dart)', () {
      final original = monitoring;

      final replacement = NoOpMonitoringService();
      monitoring = replacement;
      expect(identical(monitoring, replacement), isTrue);

      monitoring = original;
      expect(identical(monitoring, original), isTrue);
    });
  });
}
