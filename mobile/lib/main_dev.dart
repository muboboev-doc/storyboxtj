import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybox_app/app.dart';
import 'package:storybox_app/flavors.dart';

/// Точка входа для DEV-flavor.
///
/// Запуск:
///   flutter run --target lib/main_dev.dart -d chrome
///   flutter run --target lib/main_dev.dart   (на подключенном Android)
void main() {
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

  runApp(const ProviderScope(child: StoryBoxApp()));
}
