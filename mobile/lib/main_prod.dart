import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybox_app/app.dart';
import 'package:storybox_app/flavors.dart';

/// Точка входа для PROD-flavor (Play Store / RuStore / Galaxy Store / Web).
/// Локальные банки видимы.
void main() {
  kAppConfig = const AppConfig(
    flavor: Flavor.prod,
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.example.com',
    ),
    localPaymentsEnabled: true,
  );

  runApp(const ProviderScope(child: StoryBoxApp()));
}
