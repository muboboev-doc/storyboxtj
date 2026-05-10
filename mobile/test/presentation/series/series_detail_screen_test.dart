// Phase 2.10: widget tests на SeriesDetailScreen.
//
// Подменяем seriesShowProvider через ProviderScope.overrides для каждого
// сценария: loading / data / 404-error / generic-error.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storybox_app/api/storybox_api.dart';
import 'package:storybox_app/presentation/series/series_detail_screen.dart';
import 'package:storybox_app/presentation/series/series_provider.dart';

void main() {
  group('SeriesDetailScreen', () {
    testWidgets('shows progress indicator while loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            seriesShowProvider(1).overrideWith(
              (ref) => Completer<SeriesShow>().future,
            ),
          ],
          child: const MaterialApp(home: SeriesDetailScreen(id: 1)),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'renders title, synopsis, genres and free episode tile on data',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(420, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              seriesShowProvider(1).overrideWith(
                (ref) async => _buildSeries(),
              ),
            ],
            child: const MaterialApp(home: SeriesDetailScreen(id: 1)),
          ),
        );
        await tester.pumpAndSettle();

        // Title (visible в FlexibleSpaceBar и иногда в AppBar).
        expect(find.text('Test Series'), findsWidgets);

        // Synopsis.
        expect(find.text('A great story.'), findsOneWidget);

        // Genres chips.
        expect(find.text('Драма'), findsOneWidget);
        expect(find.text('Романтика'), findsOneWidget);

        // VIP-бейдж нет (default not premium).
        expect(find.text('VIP'), findsNothing);

        // Свободный эпизод (number=1).
        expect(find.text('Free'), findsOneWidget);

        // Платный эпизод — Lock + 30.
        expect(find.byIcon(Icons.lock), findsOneWidget);
        expect(find.text('30'), findsOneWidget);
      },
    );

    testWidgets('renders VIP badge when series.isPremium', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            seriesShowProvider(2).overrideWith(
              (ref) async => const SeriesShow(
                summary: SeriesSummary(
                  id: 2,
                  title: 'Premium Drama',
                  synopsis: null,
                  posterUrl: null,
                  bannerUrl: null,
                  freeEpisodesCount: 0,
                  totalEpisodes: 0,
                  isPremium: true,
                  publishedAt: null,
                ),
                genres: [],
                episodes: [],
              ),
            ),
          ],
          child: const MaterialApp(home: SeriesDetailScreen(id: 2)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VIP'), findsOneWidget);
    });

    testWidgets('shows no-episodes placeholder when empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            seriesShowProvider(3).overrideWith(
              (ref) async => const SeriesShow(
                summary: SeriesSummary(
                  id: 3,
                  title: 'Empty Series',
                  synopsis: null,
                  posterUrl: null,
                  bannerUrl: null,
                  freeEpisodesCount: 0,
                  totalEpisodes: 0,
                  isPremium: false,
                  publishedAt: null,
                ),
                genres: [],
                episodes: [],
              ),
            ),
          ],
          child: const MaterialApp(home: SeriesDetailScreen(id: 3)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Эпизоды появятся после транскода.'), findsOneWidget);
    });

    testWidgets('shows 404 message and Back button on 404 ApiError', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            seriesShowProvider(99).overrideWithValue(
              const AsyncValue<SeriesShow>.error(
                ApiError(
                  code: 'NOT_FOUND',
                  message: 'Not found',
                  statusCode: 404,
                ),
                StackTrace.empty,
              ),
            ),
          ],
          child: const MaterialApp(home: SeriesDetailScreen(id: 99)),
        ),
      );
      await tester.pump();

      expect(
        find.text('Сериал не найден или ещё не опубликован.'),
        findsOneWidget,
      );
      expect(find.text('Назад'), findsOneWidget);
      expect(find.text('Повторить'), findsNothing);
    });

    testWidgets('shows retry button on generic error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            seriesShowProvider(99).overrideWithValue(
              const AsyncValue<SeriesShow>.error(
                ApiError(code: 'NETWORK_ERROR', message: 'No internet'),
                StackTrace.empty,
              ),
            ),
          ],
          child: const MaterialApp(home: SeriesDetailScreen(id: 99)),
        ),
      );
      await tester.pump();

      expect(find.text('No internet'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
      expect(find.text('Назад'), findsNothing);
    });
  });
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

SeriesShow _buildSeries() => const SeriesShow(
  summary: SeriesSummary(
    id: 1,
    title: 'Test Series',
    synopsis: 'A great story.',
    posterUrl: null,
    bannerUrl: null,
    freeEpisodesCount: 3,
    totalEpisodes: 2,
    isPremium: false,
    publishedAt: null,
  ),
  genres: [
    Genre(id: 1, slug: 'drama', name: 'Драма'),
    Genre(id: 2, slug: 'romance', name: 'Романтика'),
  ],
  episodes: [
    Episode(
      id: 10,
      number: 1,
      title: null,
      synopsis: null,
      durationSec: 90,
      isFree: true,
      unlockCostCoins: 0,
      publishedAt: null,
    ),
    Episode(
      id: 11,
      number: 2,
      title: null,
      synopsis: null,
      durationSec: 95,
      isFree: false,
      unlockCostCoins: 30,
      publishedAt: null,
    ),
  ],
);
