<?php

declare(strict_types=1);

/*
 * Phase 2.4 (TDD red): спецификация GET /api/v1/series/{id}.
 * Phase 2.5 — реализация.
 *
 * Контракт:
 *   GET /api/v1/series/{id}
 *   →
 *   200 {
 *     id, title, synopsis, poster_url, banner_url,
 *     free_episodes_count, total_episodes, is_premium, published_at,
 *     genres: [{id, slug, name}],
 *     episodes: [{id, number, title, synopsis, duration_sec, is_free,
 *                 unlock_cost_coins, published_at}]
 *   }
 *   404 — series не существует или status != published
 *
 * Public endpoint (auth опциональна; на Phase 2 одинаково для всех).
 */

use App\Enums\EpisodeStatus;
use App\Enums\SeriesStatus;
use App\Models\Episode;
use App\Models\Genre;
use App\Models\Series;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

describe('GET /api/v1/series/{id} — happy path', function (): void {
    it('returns 200 with full series shape', function (): void {
        $series = Series::factory()->published()->create([
            'free_episodes_count' => 3,
            'is_premium' => false,
        ]);

        $response = $this->getJson("/api/v1/series/{$series->id}")
            ->assertOk();

        $response->assertJsonStructure([
            'id',
            'title',
            'synopsis',
            'poster_url',
            'banner_url',
            'free_episodes_count',
            'total_episodes',
            'is_premium',
            'published_at',
            'genres',
            'episodes',
        ]);

        expect($response->json('id'))->toBe($series->id)
            ->and($response->json('free_episodes_count'))->toBe(3)
            ->and($response->json('is_premium'))->toBeFalse();
    });

    it('includes attached genres with translated names', function (): void {
        $series = Series::factory()->published()->create();
        $drama = Genre::factory()->drama()->create();
        $romance = Genre::factory()->romance()->create();
        $series->genres()->attach([$drama->id, $romance->id]);

        $response = $this->getJson("/api/v1/series/{$series->id}")->assertOk();

        $genres = collect($response->json('genres'));
        expect($genres)->toHaveCount(2);
        expect($genres->pluck('slug')->all())
            ->toContain('drama')
            ->toContain('romance');

        // Каждый genre имеет id, slug, name.
        $first = $genres->first();
        expect($first)->toHaveKeys(['id', 'slug', 'name'])
            ->and($first['name'])->toBeString();
    });

    it('includes only ready episodes ordered by number ASC', function (): void {
        $series = Series::factory()->published()->create();

        Episode::factory()->for($series)->create(['number' => 3, 'status' => EpisodeStatus::Ready]);
        Episode::factory()->for($series)->create(['number' => 1, 'status' => EpisodeStatus::Ready]);
        Episode::factory()->for($series)->create(['number' => 2, 'status' => EpisodeStatus::Transcoding]);
        Episode::factory()->for($series)->create(['number' => 4, 'status' => EpisodeStatus::Failed]);

        $episodes = $this->getJson("/api/v1/series/{$series->id}")
            ->assertOk()
            ->json('episodes');

        // Только status=ready (числа 1 и 3).
        $numbers = collect($episodes)->pluck('number')->all();
        expect($numbers)->toBe([1, 3]);
    });

    it('episode object has expected fields', function (): void {
        $series = Series::factory()->published()->create();
        Episode::factory()->for($series)->create([
            'number' => 1,
            'duration_sec' => 90,
            'is_free' => true,
            'unlock_cost_coins' => 0,
            'status' => EpisodeStatus::Ready,
        ]);

        $first = $this->getJson("/api/v1/series/{$series->id}")
            ->assertOk()
            ->json('episodes.0');

        expect($first)->toHaveKeys([
            'id',
            'number',
            'title',
            'synopsis',
            'duration_sec',
            'is_free',
            'unlock_cost_coins',
            'published_at',
        ]);

        expect($first['number'])->toBe(1)
            ->and($first['duration_sec'])->toBe(90)
            ->and($first['is_free'])->toBeTrue();
    });
});

describe('GET /api/v1/series/{id} — 404 cases', function (): void {
    it('returns 404 for non-existent series', function (): void {
        $this->getJson('/api/v1/series/999999')->assertStatus(404);
    });

    it('returns 404 for draft series', function (): void {
        $series = Series::factory()->create(['status' => SeriesStatus::Draft]);
        $this->getJson("/api/v1/series/{$series->id}")->assertStatus(404);
    });

    it('returns 404 for archived series', function (): void {
        $series = Series::factory()->archived()->create();
        $this->getJson("/api/v1/series/{$series->id}")->assertStatus(404);
    });
});

describe('GET /api/v1/series/{id} — translations', function (): void {
    it('returns title as plain string (not JSON)', function (): void {
        $series = Series::factory()->published()->create([
            'title' => ['ru' => 'Любовь', 'en' => 'Love'],
        ]);

        $title = $this->getJson("/api/v1/series/{$series->id}")
            ->assertOk()
            ->json('title');

        expect($title)->toBeString()
            ->not->toBeEmpty();
    });
});
