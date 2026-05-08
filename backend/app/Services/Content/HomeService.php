<?php

declare(strict_types=1);

namespace App\Services\Content;

use App\Enums\SeriesStatus;
use App\Models\Genre;
use App\Models\Series;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;

/**
 * Контейнер бизнес-логики для `GET /api/v1/home`.
 *
 * 5 секций:
 *  - continue_watching — Phase 5 (user_watch_history). Сейчас всегда [].
 *  - trending          — top published, ordered by position ASC
 *  - new_releases      — published за последние 30 дней, по published_at DESC
 *  - recommended       — placeholder (top published; Phase 5+ — content-based)
 *  - genres            — active genres (with их series), ordered by position ASC
 *
 * Кэш: ключ `home:v1:{locale}` с TTL 5 минут. Инвалидируется через
 * SeriesObserver при saved / deleted.
 */
final class HomeService
{
    public const CACHE_KEY_PREFIX = 'home:v1:';
    public const CACHE_TTL_SECONDS = 300;
    private const TRENDING_LIMIT = 20;
    private const NEW_LIMIT = 20;
    private const NEW_DAYS_WINDOW = 30;
    private const RECOMMENDED_LIMIT = 20;
    private const GENRE_SERIES_LIMIT = 20;

    /** @return array{continue_watching: array<int, array<string, mixed>>, trending: array<int, array<string, mixed>>, new_releases: array<int, array<string, mixed>>, recommended: array<int, array<string, mixed>>, genres: array<int, array{genre: array<string, mixed>, series: array<int, array<string, mixed>>}>} */
    public function payload(string $locale): array
    {
        return Cache::remember(
            $this->cacheKey($locale),
            self::CACHE_TTL_SECONDS,
            fn (): array => $this->buildPayload($locale),
        );
    }

    /** Сбрасывает все home-кэши (вызывается из SeriesObserver). */
    public function flushAllLocales(): void
    {
        // На старте — поддерживаем 6 локалей (CLAUDE.md §11). Cache-стор Redis
        // не позволяет искать по pattern в стандартном ArrayStore, поэтому
        // делаем точечный forget для каждой локали.
        foreach (['ru', 'en', 'tg', 'uz', 'kk', 'ky'] as $loc) {
            Cache::forget($this->cacheKey($loc));
        }
    }

    /** @return array<string, mixed> */
    private function buildPayload(string $locale): array
    {
        $trending = $this->trending();
        $newReleases = $this->newReleases();
        $recommended = $this->recommended();
        $genres = $this->genresWithSeries();

        return [
            'continue_watching' => [],
            'trending' => $this->formatSeriesList($trending, $locale),
            'new_releases' => $this->formatSeriesList($newReleases, $locale),
            'recommended' => $this->formatSeriesList($recommended, $locale),
            'genres' => $genres
                ->map(fn (Genre $g): array => [
                    'genre' => $this->formatGenre($g, $locale),
                    'series' => $this->formatSeriesList(
                        $g->series->take(self::GENRE_SERIES_LIMIT),
                        $locale,
                    ),
                ])
                ->all(),
        ];
    }

    /** @return Collection<int, Series> */
    private function trending(): Collection
    {
        return Series::query()
            ->where('status', SeriesStatus::Published)
            ->orderBy('position')
            ->limit(self::TRENDING_LIMIT)
            ->get();
    }

    /** @return Collection<int, Series> */
    private function newReleases(): Collection
    {
        return Series::query()
            ->where('status', SeriesStatus::Published)
            ->where('published_at', '>=', Carbon::now()->subDays(self::NEW_DAYS_WINDOW))
            ->orderByDesc('published_at')
            ->limit(self::NEW_LIMIT)
            ->get();
    }

    /** @return Collection<int, Series> */
    private function recommended(): Collection
    {
        // Placeholder: те же top-published. Phase 5+ заменим на
        // collaborative-/content-based filtering.
        return Series::query()
            ->where('status', SeriesStatus::Published)
            ->orderBy('position')
            ->limit(self::RECOMMENDED_LIMIT)
            ->get();
    }

    /** @return Collection<int, Genre> */
    private function genresWithSeries(): Collection
    {
        return Genre::query()
            ->where('is_active', true)
            ->with(['series' => function ($query): void {
                $query->where('status', SeriesStatus::Published)
                    ->orderBy('position');
            }])
            ->orderBy('position')
            ->get();
    }

    /**
     * @param  Collection<int, Series>  $series
     * @return array<int, array<string, mixed>>
     */
    private function formatSeriesList(Collection $series, string $locale): array
    {
        return $series
            ->map(fn (Series $s): array => $this->formatSeries($s, $locale))
            ->values()
            ->all();
    }

    /** @return array<string, mixed> */
    private function formatSeries(Series $series, string $locale): array
    {
        return [
            'id' => $series->id,
            'title' => $series->getTranslation('title', $locale, useFallbackLocale: true),
            'synopsis' => $series->synopsis === null
                ? null
                : $series->getTranslation('synopsis', $locale, useFallbackLocale: true),
            'poster_url' => $series->poster_url,
            'banner_url' => $series->banner_url,
            'free_episodes_count' => (int) $series->free_episodes_count,
            'total_episodes' => (int) $series->total_episodes,
            'is_premium' => (bool) $series->is_premium,
            'published_at' => $series->published_at?->toIso8601String(),
        ];
    }

    /** @return array<string, mixed> */
    private function formatGenre(Genre $genre, string $locale): array
    {
        return [
            'id' => $genre->id,
            'slug' => $genre->slug,
            'name' => $genre->getTranslation('name', $locale, useFallbackLocale: true),
        ];
    }

    private function cacheKey(string $locale): string
    {
        return self::CACHE_KEY_PREFIX.$locale;
    }
}
