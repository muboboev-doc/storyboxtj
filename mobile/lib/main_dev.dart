import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybox_app/app.dart';
import 'package:storybox_app/core/monitoring/monitoring_service.dart';
import 'package:storybox_app/core/monitoring/sentry_monitoring_service.dart';
import 'package:storybox_app/flavors.dart';

/// Точка входа для DEV-flavor.
///
/// Запуск:
///   flutter run --target lib/main_dev.dart -d chrome
///   flutter run --target lib/main_dev.dart   (на подключенном Android)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  kAppConfig = const AppConfig(
    flavor: Flavor.dev,
    // На Web — backend по адресу http://localhost:8080.
    // Для Android-эмулятора 10.0.2.2 = host loopback (см. Android docs).
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
    localPaymentsEnabled: true,
  );

  // SENTRY_DSN передаётся через --dart-define при запуске.
  // На dev обычно пусто → SDK no-op, но ошибки логируются в debug console.
  const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  if (sentryDsn.isNotEmpty) {
    monitoring = SentryMonitoringService(
      dsn: sentryDsn,
      environment: 'dev',
    );
  }
  await monitoring.initialize();

  runApp(const ProviderScope(child: StoryBoxApp()));
}
