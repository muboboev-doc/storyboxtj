/// Content DTO для StoryBox API. Phase 2.8.
///
/// Соответствует `docs/openapi.yaml` v0.0.3, секция Content. Используется
/// в endpoint'ах:
///   - `GET /api/v1/home`           → [HomePayload]
///   - `GET /api/v1/series/{id}`    → [SeriesShow]
///   - `GET /api/v1/episodes/{id}`  → [EpisodeShow]
///
/// Hand-written контракт. При переходе на openapi-generator (когда станет
/// нужно — phase 4+) DTO имена и поля останутся прежними.
library;

// ─── Genre ────────────────────────────────────────────────────────────────────

/// Жанр сериала. Translatable name выдаётся в текущей локали.
final class Genre {
  const Genre({required this.id, required this.slug, required this.name});

  factory Genre.fromJson(Map<String, dynamic> json) => Genre(
    id: (json['id'] as num).toInt(),
    slug: json['slug'] as String,
    name: json['name'] as String,
  );

  final int id;
  final String slug;

  /// Локализованное имя в текущей локали (translation fallback → ru).
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'slug': slug, 'name': name};
}

// ─── Stream quality + EpisodeStream ───────────────────────────────────────────

/// HLS quality variant.
enum StreamQuality {
  sd240,
  sd480,
  hd720,
  hd1080
  ;

  static StreamQuality fromString(String value) => switch (value) {
    '240p' => StreamQuality.sd240,
    '480p' => StreamQuality.sd480,
    '720p' => StreamQuality.hd720,
    '1080p' => StreamQuality.hd1080,
    _ => StreamQuality.sd480,
  };

  String toJson() => switch (this) {
    StreamQuality.sd240 => '240p',
    StreamQuality.sd480 => '480p',
    StreamQuality.hd720 => '720p',
    StreamQuality.hd1080 => '1080p',
  };
}

/// HLS-поток одного качества для эпизода.
final class EpisodeStream {
  const EpisodeStream({
    required this.quality,
    required this.manifestUrl,
    required this.drmProtected,
  });

  factory EpisodeStream.fromJson(Map<String, dynamic> json) => EpisodeStream(
    quality: StreamQuality.fromString(json['quality'] as String),
    manifestUrl: json['manifest_url'] as String,
    drmProtected: json['drm_protected'] as bool,
  );

  final StreamQuality quality;

  /// HLS master.m3u8 URL. Phase 2 — stub. Phase 4 — signed Bunny URL.
  final String manifestUrl;

  /// Phase 8: Widevine для android, FairPlay для iOS.
  final bool drmProtected;
}

// ─── Series ───────────────────────────────────────────────────────────────────

/// Уменьшенная карточка сериала для feed-ов и cross-references.
final class SeriesSummary {
  const SeriesSummary({
    required this.id,
    required this.title,
    required this.synopsis,
    required this.posterUrl,
    required this.bannerUrl,
    required this.freeEpisodesCount,
    required this.totalEpisodes,
    required this.isPremium,
    required this.publishedAt,
  });

  factory SeriesSummary.fromJson(Map<String, dynamic> json) => SeriesSummary(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String,
    synopsis: json['synopsis'] as String?,
    posterUrl: json['poster_url'] as String?,
    bannerUrl: json['banner_url'] as String?,
    freeEpisodesCount: (json['free_episodes_count'] as num).toInt(),
    totalEpisodes: (json['total_episodes'] as num).toInt(),
    isPremium: json['is_premium'] as bool,
    publishedAt: json['published_at'] != null
        ? DateTime.parse(json['published_at'] as String)
        : null,
  );

  final int id;
  final String title;
  final String? synopsis;
  final String? posterUrl;
  final String? bannerUrl;
  final int freeEpisodesCount;
  final int totalEpisodes;
  final bool isPremium;
  final DateTime? publishedAt;
}

/// Эпизод как часть series-show. Без streams.
final class Episode {
  const Episode({
    required this.id,
    required this.number,
    required this.title,
    required this.synopsis,
    required this.durationSec,
    required this.isFree,
    required this.unlockCostCoins,
    required this.publishedAt,
  });

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
    id: (json['id'] as num).toInt(),
    number: (json['number'] as num).toInt(),
    title: json['title'] as String?,
    synopsis: json['synopsis'] as String?,
    durationSec: (json['duration_sec'] as num).toInt(),
    isFree: json['is_free'] as bool,
    unlockCostCoins: (json['unlock_cost_coins'] as num).toInt(),
    publishedAt: json['published_at'] != null
        ? DateTime.parse(json['published_at'] as String)
        : null,
  );

  final int id;
  final int number;
  final String? title;
  final String? synopsis;
  final int durationSec;
  final bool isFree;

  /// Phase 3: используется при HTTP 403 EPISODE_LOCKED для отображения
  /// «разблокировать за X коинов».
  final int unlockCostCoins;
  final DateTime? publishedAt;
}

/// Полный ответ `GET /api/v1/series/{id}`.
final class SeriesShow {
  const SeriesShow({
    required this.summary,
    required this.genres,
    required this.episodes,
  });

  factory SeriesShow.fromJson(Map<String, dynamic> json) => SeriesShow(
    summary: SeriesSummary.fromJson(json),
    genres: (json['genres'] as List<dynamic>)
        .map((e) => Genre.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    episodes: (json['episodes'] as List<dynamic>)
        .map((e) => Episode.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );

  /// Все поля SeriesSummary.
  final SeriesSummary summary;

  /// Привязанные жанры.
  final List<Genre> genres;

  /// Только ready-эпизоды, отсортированы по `number ASC`.
  final List<Episode> episodes;
}

/// Минимальная ссылка на сериал внутри episode-show.
final class SeriesShortRef {
  const SeriesShortRef({
    required this.id,
    required this.title,
    required this.posterUrl,
  });

  factory SeriesShortRef.fromJson(Map<String, dynamic> json) => SeriesShortRef(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String,
    posterUrl: json['poster_url'] as String?,
  );

  final int id;
  final String title;
  final String? posterUrl;
}

/// Полный ответ `GET /api/v1/episodes/{id}` (только если access granted).
final class EpisodeShow {
  const EpisodeShow({
    required this.episode,
    required this.series,
    required this.streams,
  });

  factory EpisodeShow.fromJson(Map<String, dynamic> json) => EpisodeShow(
    episode: Episode.fromJson(json),
    series: SeriesShortRef.fromJson(json['series'] as Map<String, dynamic>),
    streams: (json['streams'] as List<dynamic>)
        .map((e) => EpisodeStream.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );

  /// Поля Episode.
  final Episode episode;

  /// Сводка о сериале (для navigation back / breadcrumbs).
  final SeriesShortRef series;

  /// HLS-варианты для адаптивного плеера.
  final List<EpisodeStream> streams;
}

// ─── Home ─────────────────────────────────────────────────────────────────────

/// Секция «Жанр + его сериалы» внутри HomePayload.
final class HomeGenreSection {
  const HomeGenreSection({required this.genre, required this.series});

  factory HomeGenreSection.fromJson(Map<String, dynamic> json) =>
      HomeGenreSection(
        genre: Genre.fromJson(json['genre'] as Map<String, dynamic>),
        series: (json['series'] as List<dynamic>)
            .map((e) => SeriesSummary.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  final Genre genre;
  final List<SeriesSummary> series;
}

/// 5-секционная главная.
final class HomePayload {
  const HomePayload({
    required this.continueWatching,
    required this.trending,
    required this.newReleases,
    required this.recommended,
    required this.genres,
  });

  factory HomePayload.fromJson(Map<String, dynamic> json) => HomePayload(
    continueWatching: _seriesList(json['continue_watching']),
    trending: _seriesList(json['trending']),
    newReleases: _seriesList(json['new_releases']),
    recommended: _seriesList(json['recommended']),
    genres: (json['genres'] as List<dynamic>)
        .map((e) => HomeGenreSection.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );

  /// Phase 5+ заполнится из user_watch_history. На Phase 2 — всегда `[]`.
  final List<SeriesSummary> continueWatching;

  /// Top published, ordered by `position ASC`.
  final List<SeriesSummary> trending;

  /// Published за последние 30 дней, by `published_at DESC`.
  final List<SeriesSummary> newReleases;

  /// Phase 5+ — content-based recommender. Phase 2 — placeholder = top published.
  final List<SeriesSummary> recommended;

  /// Active жанры с их published-сериалами, ordered by `genre.position ASC`.
  final List<HomeGenreSection> genres;

  static List<SeriesSummary> _seriesList(dynamic raw) => (raw as List<dynamic>)
      .map((e) => SeriesSummary.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}
