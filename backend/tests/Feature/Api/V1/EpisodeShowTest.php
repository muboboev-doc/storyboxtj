<?php

declare(strict_types=1);

/*
 * Phase 2.4 (TDD red): спецификация GET /api/v1/episodes/{id}.
 * Phase 2.5 — реализация.
 *
 * Контракт:
 *   GET /api/v1/episodes/{id}
 *   →
 *   200 {
 *     id, number, title, synopsis, duration_sec,
 *     is_free, unlock_cost_coins, published_at,
 *     series: {id, title, poster_url},
 *     streams: [{quality, manifest_url, drm_protected}]
 *   }
 *   404 — episode не существует или status != ready
 *   403 EPISODE_LOCKED — paid эпизод без unlock (Phase 3 добавит проверку unlock'а)
 *
 * Phase 2 baseline:
 *   - Free episode → 200 для всех (auth не нужен)
 *   - Paid episode → 403 EPISODE_LOCKED для всех
 *     (Phase 3 EpisodeUnlockService добавит: VIP / coins-unlock / ad-unlock)
 *   - Series не published → 404 (нельзя просочиться к эпизоду draft-сериала)
 */

use App\Enums\EpisodeStatus;
use App\Enums\StreamQuality;
use App\Models\Episode;
use App\Models\EpisodeStream;
use App\Models\Series;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

describe('GET /api/v1/episodes/{id} — free episode (always playable)', function (): void {
    it('returns 200 with full episode shape including streams', function (): void {
        $series = Series::factory()->published()->create();
        $episode = Episode::factory()
            ->for($series)
            ->create([
                'is_free' => true,
                'duration_sec' => 90,
                'status' => EpisodeStatus::Ready,
            ]);
        EpisodeStream::factory()
            ->for($episode)
            ->create(['quality' => StreamQuality::Sd480]);
        EpisodeStream::factory()
            ->for($episode)
            ->create(['quality' => StreamQuality::Hd720]);

        $response = $this->getJson("/api/v1/episodes/{$episode->id}")->assertOk();

        $response->assertJsonStructure([
            'id',
            'number',
            'title',
            'synopsis',
            'duration_sec',
            'is_free',
            'unlock_cost_coins',
            'published_at',
            'series' => ['id', 'title', 'poster_url'],
            'streams' => [
                '*' => ['quality', 'manifest_url', 'drm_protected'],
            ],
        ]);

        expect($response->json('is_free'))->toBeTrue()
            ->and($response->json('series.id'))->toBe($series->id);

        $qualities = collect($response->json('streams'))->pluck('quality')->all();
        expect($qualities)
            ->toContain('480p')
            ->toContain('720p');
    });

    it('does not require authentication for free episodes', function (): void {
        $series = Series::factory()->published()->create();
        $episode = Episode::factory()
            ->for($series)
            ->create(['is_free' => true, 'status' => EpisodeStatus::Ready]);

        // Без Sanctum-токена.
        $this->getJson("/api/v1/episodes/{$episode->id}")->assertOk();
    });
});

describe('GET /api/v1/episodes/{id} — paid episode (locked in Phase 2)', function (): void {
    it('returns 403 EPISODE_LOCKED for paid episode without unlock', function (): void {
        $series = Series::factory()->published()->create();
        $episode = Episode::factory()
            ->for($series)
            ->create([
                'is_free' => false,
                'unlock_cost_coins' => 30,
                'status' => EpisodeStatus::Ready,
            ]);

        $this->getJson("/api/v1/episodes/{$episode->id}")
            ->assertStatus(403)
            ->assertJsonPath('error.code', 'EPISODE_LOCKED');
    });

    it('does not leak streams in 403 response', function (): void {
        $series = Series::factory()->published()->create();
        $episode = Episode::factory()
            ->for($series)
            ->create(['is_free' => false, 'status' => EpisodeStatus::Ready]);
        EpisodeStream::factory()->for($episode)->create();

        $body = $this->getJson("/api/v1/episodes/{$episode->id}")
            ->assertStatus(403)
            ->json();

        expect($body)->toHaveKey('error')
            ->and($body)->not->toHaveKey('streams');
    });
});

describe('GET /api/v1/episodes/{id} — 404 cases', function (): void {
    it('returns 404 for non-existent episode', function (): void {
        $this->getJson('/api/v1/episodes/999999')->assertStatus(404);
    });

    it('returns 404 for episode in unpublished series', function (): void {
        $series = Series::factory()->create();  // status=draft
        $episode = Episode::factory()
            ->for($series)
            ->create(['is_free' => true, 'status' => EpisodeStatus::Ready]);

        $this->getJson("/api/v1/episodes/{$episode->id}")->assertStatus(404);
    });

    it('returns 404 for episode with non-ready status', function (): void {
        $series = Series::factory()->published()->create();
        $episode = Episode::factory()
            ->for($series)
            ->create(['status' => EpisodeStatus::Transcoding]);

        $this->getJson("/api/v1/episodes/{$episode->id}")->assertStatus(404);
    });
});
