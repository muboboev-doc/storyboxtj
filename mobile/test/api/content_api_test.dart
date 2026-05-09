// Phase 2.8: тесты на content DTO (Home/Series/Episode/Stream).
// Контракт совпадает с docs/openapi.yaml v0.0.3, секция Content.
//
// Бэкенд-тесты — feature-тесты в backend/tests/Feature/Api/V1/*.
// Здесь — Dart-парсинг.

import 'package:flutter_test/flutter_test.dart';
import 'package:storybox_app/api/storybox_api.dart';

void main() {
  group('Genre.fromJson', () {
    test('parses translated name in current locale', () {
      final genre = Genre.fromJson({'id': 1, 'slug': 'drama', 'name': 'Драма'});
      expect(genre.id, 1);
      expect(genre.slug, 'drama');
      expect(genre.name, 'Драма');
    });

    test('roundtrip via toJson preserves data', () {
      const original = Genre(id: 5, slug: 'romance', name: 'Romance');
      final clone = Genre.fromJson(original.toJson());
      expect(clone.id, 5);
      expect(clone.slug, 'romance');
      expect(clone.name, 'Romance');
    });
  });

  group('StreamQuality enum', () {
    test('parses all 4 quality values', () {
      expect(StreamQuality.fromString('240p'), StreamQuality.sd240);
      expect(StreamQuality.fromString('480p'), StreamQuality.sd480);
      expect(StreamQuality.fromString('720p'), StreamQuality.hd720);
      expect(StreamQuality.fromString('1080p'), StreamQuality.hd1080);
    });

    test('toJson roundtrips', () {
      for (final q in StreamQuality.values) {
        expect(StreamQuality.fromString(q.toJson()), q);
      }
    });

    test('falls back to 480p on unknown value (defensive)', () {
      expect(StreamQuality.fromString('weird'), StreamQuality.sd480);
    });
  });

  group('EpisodeStream.fromJson', () {
    test('parses stub Phase 2 manifest_url', () {
      final stream = EpisodeStream.fromJson({
        'quality': '720p',
        'manifest_url':
            'https://stub-cdn.storybox.tj/episodes/abc/720p/master.m3u8',
        'drm_protected': false,
      });
      expect(stream.quality, StreamQuality.hd720);
      expect(stream.manifestUrl, contains('master.m3u8'));
      expect(stream.drmProtected, isFalse);
    });
  });

  group('SeriesSummary.fromJson', () {
    test('parses minimum-shape series for feed', () {
      final series = SeriesSummary.fromJson({
        'id': 42,
        'title': 'Ночной таксист',
        'synopsis': 'История водителя ночного такси.',
        'poster_url': 'https://cdn.example.com/posters/42.jpg',
        'banner_url': null,
        'free_episodes_count': 3,
        'total_episodes': 12,
        'is_premium': false,
        'published_at': '2026-04-01T10:00:00+00:00',
      });

      expect(series.id, 42);
      expect(series.title, 'Ночной таксист');
      expect(series.synopsis, contains('водителя'));
      expect(series.posterUrl, contains('posters/42.jpg'));
      expect(series.bannerUrl, isNull);
      expect(series.freeEpisodesCount, 3);
      expect(series.totalEpisodes, 12);
      expect(series.isPremium, isFalse);
      expect(series.publishedAt?.toUtc().year, 2026);
    });

    test('handles null synopsis / poster_url / published_at', () {
      final series = SeriesSummary.fromJson({
        'id': 1,
        'title': 'Untitled',
        'synopsis': null,
        'poster_url': null,
        'banner_url': null,
        'free_episodes_count': 0,
        'total_episodes': 0,
        'is_premium': true,
        'published_at': null,
      });

      expect(series.synopsis, isNull);
      expect(series.posterUrl, isNull);
      expect(series.publishedAt, isNull);
      expect(series.isPremium, isTrue);
    });
  });

  group('Episode.fromJson', () {
    test('parses episode in series-show context', () {
      final ep = Episode.fromJson({
        'id': 100,
        'number': 5,
        'title': 'Серия 5',
        'synopsis': 'Преследование',
        'duration_sec': 95,
        'is_free': false,
        'unlock_cost_coins': 30,
        'published_at': null,
      });

      expect(ep.id, 100);
      expect(ep.number, 5);
      expect(ep.title, 'Серия 5');
      expect(ep.durationSec, 95);
      expect(ep.isFree, isFalse);
      expect(ep.unlockCostCoins, 30);
    });

    test('handles null title (typical for unnamed episodes)', () {
      final ep = Episode.fromJson({
        'id': 1,
        'number': 1,
        'title': null,
        'synopsis': null,
        'duration_sec': 0,
        'is_free': true,
        'unlock_cost_coins': 0,
        'published_at': null,
      });
      expect(ep.title, isNull);
      expect(ep.isFree, isTrue);
    });
  });

  group('SeriesShow.fromJson', () {
    test('parses full series-show payload with genres + episodes', () {
      final show = SeriesShow.fromJson({
        'id': 1,
        'title': 'Test Series',
        'synopsis': 'A test',
        'poster_url': 'https://cdn.example.com/p.jpg',
        'banner_url': null,
        'free_episodes_count': 3,
        'total_episodes': 2,
        'is_premium': false,
        'published_at': '2026-04-01T10:00:00+00:00',
        'genres': [
          {'id': 1, 'slug': 'drama', 'name': 'Драма'},
          {'id': 2, 'slug': 'romance', 'name': 'Романтика'},
        ],
        'episodes': [
          {
            'id': 10,
            'number': 1,
            'title': null,
            'synopsis': null,
            'duration_sec': 90,
            'is_free': true,
            'unlock_cost_coins': 0,
            'published_at': null,
          },
          {
            'id': 11,
            'number': 2,
            'title': null,
            'synopsis': null,
            'duration_sec': 95,
            'is_free': false,
            'unlock_cost_coins': 30,
            'published_at': null,
          },
        ],
      });

      expect(show.summary.id, 1);
      expect(show.summary.title, 'Test Series');
      expect(show.genres, hasLength(2));
      expect(show.genres.first.slug, 'drama');
      expect(show.episodes, hasLength(2));
      expect(show.episodes.first.number, 1);
      expect(show.episodes.last.number, 2);
    });

    test('handles empty genres / episodes', () {
      final show = SeriesShow.fromJson({
        'id': 1,
        'title': 'Empty',
        'synopsis': null,
        'poster_url': null,
        'banner_url': null,
        'free_episodes_count': 0,
        'total_episodes': 0,
        'is_premium': false,
        'published_at': null,
        'genres': <dynamic>[],
        'episodes': <dynamic>[],
      });
      expect(show.genres, isEmpty);
      expect(show.episodes, isEmpty);
    });
  });

  group('EpisodeShow.fromJson', () {
    test('parses episode + series + streams', () {
      final ep = EpisodeShow.fromJson({
        'id': 100,
        'number': 1,
        'title': null,
        'synopsis': null,
        'duration_sec': 90,
        'is_free': true,
        'unlock_cost_coins': 0,
        'published_at': null,
        'series': {
          'id': 1,
          'title': 'Test Series',
          'poster_url': 'https://cdn.example.com/p.jpg',
        },
        'streams': [
          {
            'quality': '480p',
            'manifest_url': 'https://stub.example.com/480p.m3u8',
            'drm_protected': false,
          },
          {
            'quality': '720p',
            'manifest_url': 'https://stub.example.com/720p.m3u8',
            'drm_protected': false,
          },
        ],
      });

      expect(ep.episode.id, 100);
      expect(ep.episode.number, 1);
      expect(ep.series.id, 1);
      expect(ep.series.title, 'Test Series');
      expect(ep.streams, hasLength(2));
      expect(ep.streams.map((s) => s.quality), [
        StreamQuality.sd480,
        StreamQuality.hd720,
      ]);
    });
  });

  group('HomePayload.fromJson', () {
    test('parses all 5 sections (continue_watching can be empty)', () {
      final payload = HomePayload.fromJson({
        'continue_watching': <dynamic>[],
        'trending': [_seriesJson(id: 1, title: 'Trending 1')],
        'new_releases': [_seriesJson(id: 2, title: 'New 1')],
        'recommended': [_seriesJson(id: 3, title: 'Reco 1')],
        'genres': [
          {
            'genre': {'id': 1, 'slug': 'drama', 'name': 'Драма'},
            'series': [_seriesJson(id: 4, title: 'Drama 1')],
          },
        ],
      });

      expect(payload.continueWatching, isEmpty);
      expect(payload.trending, hasLength(1));
      expect(payload.trending.first.title, 'Trending 1');
      expect(payload.newReleases, hasLength(1));
      expect(payload.recommended, hasLength(1));
      expect(payload.genres, hasLength(1));
      expect(payload.genres.first.genre.slug, 'drama');
      expect(payload.genres.first.series, hasLength(1));
      expect(payload.genres.first.series.first.title, 'Drama 1');
    });

    test('handles fully empty home (no published series)', () {
      final payload = HomePayload.fromJson({
        'continue_watching': <dynamic>[],
        'trending': <dynamic>[],
        'new_releases': <dynamic>[],
        'recommended': <dynamic>[],
        'genres': <dynamic>[],
      });
      expect(payload.continueWatching, isEmpty);
      expect(payload.trending, isEmpty);
      expect(payload.newReleases, isEmpty);
      expect(payload.recommended, isEmpty);
      expect(payload.genres, isEmpty);
    });
  });

  group('ApiError — context (Phase 2.5+)', () {
    test('parses EPISODE_LOCKED with unlock_cost_coins context', () {
      final err = ApiError.fromJson({
        'error': {
          'code': 'EPISODE_LOCKED',
          'message': 'This episode is locked.',
          'context': {'unlock_cost_coins': 30, 'is_premium': false},
        },
      }, 403);

      expect(err.code, 'EPISODE_LOCKED');
      expect(err.statusCode, 403);
      expect(err.context, isNotNull);
      expect(err.context!['unlock_cost_coins'], 30);
      expect(err.context!['is_premium'], isFalse);
    });

    test('handles missing context (older errors without it)', () {
      final err = ApiError.fromJson({
        'error': {'code': 'INVALID_OTP', 'message': 'Wrong code'},
      }, 422);
      expect(err.code, 'INVALID_OTP');
      expect(err.context, isNull);
    });
  });
}

// Helper для генерации SeriesSummary JSON в тестах HomePayload.
Map<String, dynamic> _seriesJson({required int id, required String title}) => {
  'id': id,
  'title': title,
  'synopsis': null,
  'poster_url': null,
  'banner_url': null,
  'free_episodes_count': 3,
  'total_episodes': 0,
  'is_premium': false,
  'published_at': null,
};
