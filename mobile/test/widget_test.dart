// Smoke widget tests для Phase 0.3.
// Phase 1+ заменим на golden tests + integration_test полного happy-path.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storybox_app/app.dart';
import 'package:storybox_app/flavors.dart';

void main() {
  setUpAll(() {
    // В тестах используем dev-конфиг.
    kAppConfig = const AppConfig(
      flavor: Flavor.dev,
      apiBaseUrl: 'http://localhost:8080',
      localPaymentsEnabled: true,
    );
  });

  testWidgets('app renders ping screen with expected widgets', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: StoryBoxApp()),
    );

    // AppBar показывает имя приложения и flavor-бейдж.
    expect(find.text('StoryBox (dev)'), findsOneWidget);
    expect(find.text('DEV'), findsOneWidget);

    // Заголовок и URL.
    expect(find.text('Phase 0.3 smoke check'), findsOneWidget);
    expect(
      find.textContaining('http://localhost:8080/api/v1/ping'),
      findsOneWidget,
    );

    // Кнопка Ping API кликабельна.
    final button = find.widgetWithText(FilledButton, 'Ping API');
    expect(button, findsOneWidget);
  });

  testWidgets('appstore flavor hides Local payments badge label correctly', (
    tester,
  ) async {
    kAppConfig = const AppConfig(
      flavor: Flavor.appstore,
      apiBaseUrl: 'https://api.example.com',
      localPaymentsEnabled: false,
    );

    await tester.pumpWidget(
      const ProviderScope(child: StoryBoxApp()),
    );

    // На appstore-flavor видим бейдж APPSTORE.
    expect(find.text('APPSTORE'), findsOneWidget);
    expect(find.text('DEV'), findsNothing);
  });
}
