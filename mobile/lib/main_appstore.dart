import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybox_app/app.dart';
import 'package:storybox_app/core/monitoring/monitoring_service.dart';
import 'package:storybox_app/core/monitoring/sentry_monitoring_service.dart';
import 'package:storybox_app/flavors.dart';

/// Точка входа для APP STORE-flavor (iOS Apple App Store).
///
/// CLAUDE.md §10.5: Reader-app pattern. Локальные банки СКРЫТЫ —
/// вместо них в Coins Store будет кнопка «Купить на сайте» → Safari
/// (без явных упоминаний банков и цен в TJS, чтобы не нарушить Guideline 3.1.1).
///
/// Сборка: flutter build ipa --target lib/main_appstore.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  kAppConfig = const AppConfig(
    flavor: Flavor.appstore,
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.example.com',
    ),
    localPaymentsEnabled: false,
  );

  const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  const sentryRelease = String.fromEnvironment('SENTRY_RELEASE');
  if (sentryDsn.isNotEmpty) {
    monitoring = SentryMonitoringService(
      dsn: sentryDsn,
      environment: 'appstore',
      release: sentryRelease.isEmpty ? null : sentryRelease,
      tracesSampleRate: 0.2,
    );
  }
  await monitoring.initialize();

  runApp(const ProviderScope(child: StoryBoxApp()));
}
