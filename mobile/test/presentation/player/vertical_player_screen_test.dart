// Phase 2.11: widget tests на VerticalPlayerScreen.
//
// Подменяем episodeShowProvider через ProviderScope.overrides для каждого
// сценария: loading / data / 404 / EPISODE_LOCKED / generic-error.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storybox_app/api/storybox_api.dart';
import 'package:storybox_app/presentation/player/episode_provider.dart';
import 'package:storybox_app/presentation/player/vertical_player_screen.dart';

void main() {
  group('VerticalPlayerScreen', () {
    testWidgets('shows progress indicator while loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            episodeShowProvider(1).overrideWith(
              (ref) => Completer<EpisodeShow>().future,
            ),
          ],
          child: const MaterialApp(home: VerticalPlayerScreen(id: 1)),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders player + series/episode meta on data', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            episodeShowProvider(10).overrideWith(
              (ref) async => _buildEpisode(),
            ),
          ],
          child: const MaterialApp(home: VerticalPlayerScreen(id: 10)),
        ),
      );
      await tester.pumpAndSettle();

      // Series title и episode title в bottom meta.
      expect(find.text('Test Series'), findsOneWidget);
      expect(find.text('Episode 1'), findsOneWidget); // fallback title
      // Play icon в центре.
      expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    });

    testWidgets(
      'shows generic error message and retry on non-locked ApiError',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              episodeShowProvider(99).overrideWithValue(
                const AsyncValue<EpisodeShow>.error(
                  ApiError(code: 'NETWORK_ERROR', message: 'Connection failed'),
                  StackTrace.empty,
                ),
              ),
            ],
            child: const MaterialApp(home: VerticalPlayerScreen(id: 99)),
          ),
        );
        await tester.pump();

        expect(find.text('Connection failed'), findsOneWidget);
        expect(find.text('Повторить'), findsOneWidget);
      },
    );

    testWidgets('shows 404 message and Back on 404', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            episodeShowProvider(99).overrideWithValue(
              const AsyncValue<EpisodeShow>.error(
                ApiError(
                  code: 'NOT_FOUND',
                  message: 'Gone',
                  statusCode: 404,
                ),
                StackTrace.empty,
              ),
            ),
          ],
          child: const MaterialApp(home: VerticalPlayerScreen(id: 99)),
        ),
      );
      await tester.pump();

      expect(find.text('Эпизод недоступен или не существует.'), findsOneWidget);
      expect(find.text('Назад'), findsOneWidget);
    });

    testWidgets('shows LockedEpisodeSheet on EPISODE_LOCKED 403', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            episodeShowProvider(50).overrideWithValue(
              const AsyncValue<EpisodeShow>.error(
                ApiError(
                  code: 'EPISODE_LOCKED',
                  message: 'Locked',
                  statusCode: 403,
                  context: {'unlock_cost_coins': 30, 'is_premium': false},
                ),
                StackTrace.empty,
              ),
            ),
          ],
          child: const MaterialApp(home: VerticalPlayerScreen(id: 50)),
        ),
      );
      // pump несколько раз чтобы postFrameCallback успел показать sheet.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Этот эпизод заблокирован'), findsOneWidget);
      expect(find.text('Разблокируйте за 30 коинов.'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      // Generic error UI скрыт.
      expect(find.text('Повторить'), findsNothing);
    });

    testWidgets(
      'shows premium variant of LockedEpisodeSheet when is_premium=true',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              episodeShowProvider(51).overrideWithValue(
                const AsyncValue<EpisodeShow>.error(
                  ApiError(
                    code: 'EPISODE_LOCKED',
                    message: 'Locked',
                    statusCode: 403,
                    context: {'unlock_cost_coins': 0, 'is_premium': true},
                  ),
                  StackTrace.empty,
                ),
              ),
            ],
            child: const MaterialApp(home: VerticalPlayerScreen(id: 51)),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('Этот эпизод — VIP-контент'), findsOneWidget);
        expect(find.byIcon(Icons.workspace_premium), findsOneWidget);
      },
    );
  });
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

EpisodeShow _buildEpisode() => const EpisodeShow(
  episode: Episode(
    id: 10,
    number: 1,
    title: null,
    synopsis: 'A short premise',
    durationSec: 90,
    isFree: true,
    unlockCostCoins: 0,
    publishedAt: null,
  ),
  series: SeriesShortRef(
    id: 1,
    title: 'Test Series',
    posterUrl: null,
  ),
  streams: [
    EpisodeStream(
      quality: StreamQuality.sd480,
      manifestUrl: 'https://stub.example.com/480p.m3u8',
      drmProtected: false,
    ),
    EpisodeStream(
      quality: StreamQuality.hd720,
      manifestUrl: 'https://stub.example.com/720p.m3u8',
      drmProtected: false,
    ),
  ],
);
