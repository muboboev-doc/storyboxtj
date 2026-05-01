// Smoke widget tests. Phase 1.7 — auth flow добавил go_router + Riverpod
// auth state, поэтому переписаны под `Unauthenticated → PhoneOtpScreen`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storybox_app/app.dart';
import 'package:storybox_app/core/storage/auth_storage.dart';
import 'package:storybox_app/flavors.dart';
import 'package:storybox_app/presentation/auth/auth_provider.dart';

void main() {
  setUpAll(() {
    // В тестах используем dev-конфиг.
    kAppConfig = const AppConfig(
      flavor: Flavor.dev,
      apiBaseUrl: 'http://localhost:8080',
      localPaymentsEnabled: true,
    );
  });

  testWidgets('app renders splash → login when no token', (tester) async {
    final storage = InMemoryAuthStorage();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStorageProvider.overrideWithValue(storage),
        ],
        child: const StoryBoxApp(),
      ),
    );

    // Сначала splash (auth = Unknown).
    expect(find.text('StoryBox'), findsWidgets);

    // После microtask restoreSession завершится → Unauthenticated → /login.
    await tester.pumpAndSettle();

    expect(find.text('Войти'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Получить код'), findsOneWidget);
  });
}
