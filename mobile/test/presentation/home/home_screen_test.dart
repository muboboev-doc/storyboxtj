// Phase 2.9: widget tests на HomeScreen.
//
// Подменяем homeProvider напрямую через ProviderScope.overrides:
//  - data → overrideWith((ref) async => HomePayload(...))
//  - loading → overrideWith с future, который никогда не резолвится
//  - error → overrideWithValue(AsyncValue<HomePayload>.error(...))
//
// Для error используем именно overrideWithValue(AsyncValue.error) — это
// инжектит финальное состояние без futures. overrideWith((ref) async => throw)
// «теряет» исключение в test-zone до того как Riverpod подпишется на future.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storybox_app/api/storybox_api.dart';
import 'package:storybox_app/presentation/home/home_provider.dart';
import 'package:storybox_app/presentation/home/home_screen.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('shows loading skeleton on initial load', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeProvider.overrideWith(
              (ref) => Completer<HomePayload>().future, // never resolves
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );

      expect(find.text('Не удалось загрузить ленту.'), findsNothing);
      expect(
        find.text('Здесь пока пусто.\nКонтент скоро появится.'),
        findsNothing,
      );
      expect(find.byType(ListView), findsWidgets);
    });

    testWidgets('shows empty state when all sections are empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeProvider.overrideWith(
              (ref) async => const HomePayload(
                continueWatching: [],
                trending: [],
                newReleases: [],
                recommended: [],
                genres: [],
              ),
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Здесь пока пусто.\nКонтент скоро появится.'),
        findsOneWidget,
      );
    });

    testWidgets('renders sections with series for non-empty payload', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final s1 = _series(id: 1, title: 'Trending One');
      final s2 = _series(id: 2, title: 'New Hot');
      final s3 = _series(id: 3, title: 'For You');
      final s4 = _series(id: 4, title: 'Drama Slot');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeProvider.overrideWith(
              (ref) async => HomePayload(
                continueWatching: const [],
                trending: [s1],
                newReleases: [s2],
                recommended: [s3],
                genres: [
                  HomeGenreSection(
                    genre: const Genre(id: 10, slug: 'drama', name: 'Драма'),
                    series: [s4],
                  ),
                ],
              ),
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trending'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);
      expect(find.text('Драма'), findsOneWidget);

      expect(find.text('Trending One'), findsOneWidget);
      expect(find.text('New Hot'), findsOneWidget);
      expect(find.text('For You'), findsOneWidget);
      expect(find.text('Drama Slot'), findsOneWidget);
    });

    testWidgets('hides Continue Watching when empty (Phase 2 default)', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeProvider.overrideWith(
              (ref) async => HomePayload(
                continueWatching: const [],
                trending: [_series(id: 1, title: 'X')],
                newReleases: const [],
                recommended: const [],
                genres: const [],
              ),
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue Watching'), findsNothing);
      expect(find.text('Trending'), findsOneWidget);
    });

    testWidgets('shows error state with retry button on ApiError', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeProvider.overrideWithValue(
              const AsyncValue<HomePayload>.error(
                ApiError(
                  code: 'NETWORK_ERROR',
                  message: 'Connection failed',
                ),
                StackTrace.empty,
              ),
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Connection failed'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('falls back to generic message for non-ApiError exceptions', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeProvider.overrideWithValue(
              AsyncValue<HomePayload>.error(
                Exception('boom'),
                StackTrace.empty,
              ),
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Не удалось загрузить ленту.'), findsOneWidget);
    });

    testWidgets('error state has working refresh icon button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeProvider.overrideWithValue(
              const AsyncValue<HomePayload>.error(
                ApiError(code: 'X', message: 'oops'),
                StackTrace.empty,
              ),
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();

      final button = find.widgetWithIcon(FilledButton, Icons.refresh);
      expect(button, findsOneWidget);
      // Тап не должен крашить.
      await tester.tap(button);
      await tester.pump();
    });
  });
}

SeriesSummary _series({required int id, required String title}) =>
    SeriesSummary(
      id: id,
      title: title,
      synopsis: null,
      posterUrl: null,
      bannerUrl: null,
      freeEpisodesCount: 3,
      totalEpisodes: 0,
      isPremium: false,
      publishedAt: null,
    );
