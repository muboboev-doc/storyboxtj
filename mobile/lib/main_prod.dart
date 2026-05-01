import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybox_app/app.dart';
import 'package:storybox_app/core/monitoring/monitoring_service.dart';
import 'package:storybox_app/core/monitoring/sentry_monitoring_service.dart';
import 'package:storybox_app/flavors.dart';

/// Точка входа для PROD-flavor (Play Store / RuStore / Galaxy Store / Web).
/// Локальные банки видимы.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  kAppConfig = const AppConfig(
    flavor: Flavor.prod,
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.example.com',
    ),
    localPaymentsEnabled: true,
  );

  const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  const sentryRelease = String.fromEnvironment('SENTRY_RELEASE');
  if (sentryDsn.isNotEmpty) {
    monitoring = SentryMonitoringService(
      dsn: sentryDsn,
      environment: 'production',
      release: sentryRelease.isEmpty ? null : sentryRelease,
      // Prod — снижаем sample rate чтобы не выгрести квоту.
      tracesSampleRate: 0.2,
    );
  }
  await monitoring.initialize();

  runApp(const ProviderScope(child: StoryBoxApp()));
}
