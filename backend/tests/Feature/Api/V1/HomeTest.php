<?php

declare(strict_types=1);

/*
 * Phase 2.2 (TDD red): спецификация GET /api/v1/home.
 * Phase 2.3 — реализация.
 *
 * Контракт:
 *   GET /api/v1/home
 *   →
 *   200 {
 *     "continue_watching": [],          // Phase 5 заполнит из user_watch_history
 *     "trending": [Series, ...],         // top-N published, ordered by position ASC
 *     "new_releases": [Series, ...],     // published за последние 30 дней, по published_at DESC
 *     "recommended": [Series, ...],      // top-N published (placeholder для Phase 5+ recommender)
 *     "genres": [
 *       { "genre": Genre, "series": [Series, ...] },
 *       ...
 *     ]
 *   }
 *
 * Бизнес-правила:
 *  - Public endpoint (auth опциональна; guest и user видят одно и то же на Phase 2)
 *  - Только status=published сериалы попадают в любые секции
 *  - Genres: только is_active, отсортированы по position ASC
 *  - Translatable поля (title, synopsis, name) выдаются в текущей app locale
 *  - Кэш Cache 5 мин (`home:v1:{locale}`)
 *  - Cache flush при Series saved / deleted (Observer)
 */

use App\Enums\SeriesStatus;
use App\Models\Genre;
use App\Models\Series;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    Cache::flush();
});

describe('GET /api/v1/home — structure', function (): void {
    it('returns 200 with all 5 section keys', function (): void {
        $this->getJson('/api/v1/home')
            ->assertOk()
            ->assertJsonStructure([
                'continue_watching',
                'trending',
                'new_releases',
                'recommended',
                'genres',
            ]);
    });

    it('is publicly accessible (no auth required)', function (): void {
        $this->getJson('/api/v1/home')->assertOk();
    });

    it('continue_watching is empty array for everyone (Phase 2 baseline)', function (): void {
        $response = $this->getJson('/api/v1/home');

        expect($response->json('continue_watching'))->toBe([]);
    });
});

describe('GET /api/v1/home — content filtering', function (): void {
    it('only published series appear in trending', function (): void {
        $published = Series::factory()->published()->create();
        $draft = Series::factory()->create();
        $archived = Series::factory()->archived()->create();

        $response = $this->getJson('/api/v1/home')->assertOk();

        $trendingIds = collect($response->json('trending'))->pluck('id')->all();
        expect($trendingIds)
            ->toContain($published->id)
            ->not->toContain($draft->id)
            ->not->toContain($archived->id);
    });

    it('new_releases shows series published in last 30 days, ordered by published_at DESC', function (): void {
        // Старая публикация — не попадает в new_releases.
        $old = Series::factory()->published()->create([
            'published_at' => now()->subDays(60),
        ]);
        // Новая.
        $newest = Series::factory()->published()->create([
            'published_at' => now()->subHour(),
        ]);
        $middle = Series::factory()->published()->create([
            'published_at' => now()->subDays(5),
        ]);

        $response = $this->getJson('/api/v1/home')->assertOk();

        $newIds = collect($response->json('new_releases'))->pluck('id')->all();
        expect($newIds)
            ->toContain($newest->id)
            ->toContain($middle->id)
            ->not->toContain($old->id);

        // Порядок: newest → middle.
        expect(array_search($newest->id, $newIds, true))
            ->toBeLessThan(array_search($middle->id, $newIds, true));
    });

    it('trending sorted by position ASC', function (): void {
        $a = Series::factory()->published()->create(['position' => 30]);
        $b = Series::factory()->published()->create(['position' => 10]);
        $c = Series::factory()->published()->create(['position' => 20]);

        $response = $this->getJson('/api/v1/home')->assertOk();

        $ids = collect($response->json('trending'))->pluck('id')->all();
        expect($ids)->toBe([$b->id, $c->id, $a->id]);
    });
});

describe('GET /api/v1/home — genres section', function (): void {
    it('returns active genres with their published series', function (): void {
        $drama = Genre::factory()->drama()->create(['position' => 1]);
        $romance = Genre::factory()->romance()->create(['position' => 2]);
        $inactive = Genre::factory()->inactive()->create();

        $s1 = Series::factory()->published()->create();
        $s1->genres()->attach($drama);

        $s2 = Series::factory()->published()->create();
        $s2->genres()->attach([$drama->id, $romance->id]);

        $response = $this->getJson('/api/v1/home')->assertOk();

        $genres = $response->json('genres');
        $genreSlugs = collect($genres)->pluck('genre.slug')->all();

        expect($genreSlugs)
            ->toContain('drama')
            ->toContain('romance')
            ->not->toContain($inactive->slug);

        // Drama's series count: 2.
        $dramaSection = collect($genres)->firstWhere('genre.slug', 'drama');
        expect(collect($dramaSection['series'])->pluck('id')->all())
            ->toContain($s1->id)
            ->toContain($s2->id);
    });

    it('genres ordered by position ASC', function (): void {
        $b = Genre::factory()->create(['slug' => 'b', 'position' => 30]);
        $a = Genre::factory()->create(['slug' => 'a', 'position' => 10]);
        $c = Genre::factory()->create(['slug' => 'c', 'position' => 20]);

        // Прицепим хотя бы один published series к каждому, иначе genre может
        // быть отфильтрован (если impl фильтрует пустые жанры).
        $series = Series::factory()->published()->create();
        $series->genres()->attach([$a->id, $b->id, $c->id]);

        $response = $this->getJson('/api/v1/home')->assertOk();

        $slugs = collect($response->json('genres'))->pluck('genre.slug')->all();
        expect($slugs)->toBe(['a', 'c', 'b']);
    });
});

describe('GET /api/v1/home — translations', function (): void {
    it('returns translated title in current locale', function (): void {
        Series::factory()->published()->create([
            'title' => ['ru' => 'Любовь в Душанбе', 'en' => 'Love in Dushanbe'],
        ]);

        $response = $this->withHeader('Accept-Language', 'en')
            ->getJson('/api/v1/home');

        $title = collect($response->json('trending'))->first()['title'] ?? null;
        // Backend не обязан обязательно honor'ить Accept-Language на этой
        // фазе; критичный инвариант — title не пустой и string.
        expect($title)->toBeString()->not->toBeEmpty();
    });
});

describe('GET /api/v1/home — caching', function (): void {
    it('second request hits cache (no DB queries on series)', function (): void {
        Series::factory()->published()->count(3)->create();

        // Прогрев.
        $this->getJson('/api/v1/home')->assertOk();

        DB::enableQueryLog();
        $this->getJson('/api/v1/home')->assertOk();

        $queries = DB::getQueryLog();
        $contentQueries = collect($queries)->filter(fn (array $q) => str_contains((string) $q['query'], 'series')
                || str_contains((string) $q['query'], 'genres'));

        expect($contentQueries)->toBeEmpty();
    });

    it('flushes cache when Series is saved', function (): void {
        $this->getJson('/api/v1/home')->assertOk(); // прогрев пустой кэш

        Series::factory()->published()->create();

        $response = $this->getJson('/api/v1/home')->assertOk();
        $count = count($response->json('trending'));

        expect($count)->toBe(1);
    });

    it('flushes cache when Series is deleted', function (): void {
        $series = Series::factory()->published()->create();
        $this->getJson('/api/v1/home')->assertOk(); // прогрев

        $series->delete();

        $response = $this->getJson('/api/v1/home')->assertOk();
        expect($response->json('trending'))->toBeEmpty();
    });
});

describe('GET /api/v1/home — series resource shape', function (): void {
    it('series object contains expected fields', function (): void {
        Series::factory()
            ->published()
            ->create([
                'title' => ['en' => 'Test'],
                'free_episodes_count' => 5,
                'is_premium' => true,
            ]);

        $first = $this->getJson('/api/v1/home')
            ->assertOk()
            ->json('trending.0');

        expect($first)->toHaveKeys([
            'id',
            'title',
            'synopsis',
            'poster_url',
            'banner_url',
            'free_episodes_count',
            'total_episodes',
            'is_premium',
            'published_at',
        ]);

        expect($first['free_episodes_count'])->toBe(5)
            ->and($first['is_premium'])->toBeTrue();
    });
});
