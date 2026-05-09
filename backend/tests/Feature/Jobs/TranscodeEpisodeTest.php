<?php

declare(strict_types=1);

/*
 * Phase 2.7 (TDD red): спецификация TranscodeEpisode job.
 * Phase 2.7 (TDD green): реализация в App\Jobs\TranscodeEpisode.
 *
 * Контракт:
 *   TranscodeEpisode::dispatch($episode)
 *   →
 *   1. status: Uploaded → Transcoding (помечается до начала работы)
 *   2. (имитация ffmpeg) — Phase 4 заменим на реальный CLI-вызов
 *   3. Создаются 4 EpisodeStream-записи: 240p / 480p / 720p / 1080p
 *      с manifest_url и segment_base_url, прицепленными к темп S3-префиксу
 *   4. status: Transcoding → Ready
 *   5. Series.total_episodes пересчитывается (counts ready-эпизодов)
 *
 * Failure-сценарий (Phase 4 будет реализован полностью):
 *   - retry policy + status → Failed после 3-го падения
 *   - на этой фазе — ловим только happy path
 */

use App\Enums\EpisodeStatus;
use App\Enums\StreamQuality;
use App\Jobs\TranscodeEpisode;
use App\Models\Episode;
use App\Models\EpisodeStream;
use App\Models\Series;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;

uses(RefreshDatabase::class);

describe('TranscodeEpisode job — happy path', function (): void {
    it('marks episode status as Ready after running', function (): void {
        $episode = Episode::factory()->create([
            'status' => EpisodeStatus::Uploaded,
            'original_url' => 'https://temp.example.com/raw.mp4',
        ]);

        (new TranscodeEpisode($episode->id))->handle();

        expect($episode->fresh()->status)->toBe(EpisodeStatus::Ready);
    });

    it('creates one EpisodeStream per quality (240p/480p/720p/1080p)', function (): void {
        $episode = Episode::factory()->create([
            'status' => EpisodeStatus::Uploaded,
            'original_url' => 'https://temp.example.com/raw.mp4',
        ]);

        (new TranscodeEpisode($episode->id))->handle();

        $streams = EpisodeStream::query()
            ->where('episode_id', $episode->id)
            ->get();

        expect($streams)->toHaveCount(4);

        $qualities = $streams->pluck('quality')->all();
        expect($qualities)
            ->toContain(StreamQuality::Sd240)
            ->toContain(StreamQuality::Sd480)
            ->toContain(StreamQuality::Hd720)
            ->toContain(StreamQuality::Hd1080);
    });

    it('each stream has non-empty manifest_url', function (): void {
        $episode = Episode::factory()->create([
            'status' => EpisodeStatus::Uploaded,
            'original_url' => 'https://temp.example.com/raw.mp4',
        ]);

        (new TranscodeEpisode($episode->id))->handle();

        $streams = EpisodeStream::query()
            ->where('episode_id', $episode->id)
            ->get();

        foreach ($streams as $stream) {
            expect($stream->manifest_url)
                ->toBeString()
                ->not->toBeEmpty();
            expect($stream->manifest_url)->toContain($stream->quality->value);
        }
    });

    it('recomputes Series.total_episodes after transcoding', function (): void {
        $series = Series::factory()->create(['total_episodes' => 0]);

        $ep1 = Episode::factory()->forSeries($series, 1)->create([
            'status' => EpisodeStatus::Uploaded,
            'original_url' => 'https://temp.example.com/raw1.mp4',
        ]);
        $ep2 = Episode::factory()->forSeries($series, 2)->create([
            'status' => EpisodeStatus::Uploaded,
            'original_url' => 'https://temp.example.com/raw2.mp4',
        ]);

        (new TranscodeEpisode($ep1->id))->handle();
        (new TranscodeEpisode($ep2->id))->handle();

        expect($series->fresh()->total_episodes)->toBe(2);
    });
});

describe('TranscodeEpisode job — idempotency', function (): void {
    it('re-running on a Ready episode does not duplicate streams', function (): void {
        $episode = Episode::factory()->create([
            'status' => EpisodeStatus::Uploaded,
            'original_url' => 'https://temp.example.com/raw.mp4',
        ]);

        (new TranscodeEpisode($episode->id))->handle();
        (new TranscodeEpisode($episode->id))->handle();

        expect(EpisodeStream::query()->where('episode_id', $episode->id)->count())
            ->toBe(4);
    });
});

describe('TranscodeEpisode job — dispatch via Observer', function (): void {
    it('dispatches the job when an Uploaded episode is created via observer', function (): void {
        Bus::fake([TranscodeEpisode::class]);

        $episode = Episode::factory()->create([
            'status' => EpisodeStatus::Uploaded,
            'original_url' => 'https://temp.example.com/raw.mp4',
        ]);

        Bus::assertDispatched(
            TranscodeEpisode::class,
            fn (TranscodeEpisode $job): bool => $job->episodeId === $episode->id,
        );
    });

    it('does not dispatch when status is Ready (no original_url)', function (): void {
        Bus::fake([TranscodeEpisode::class]);

        Episode::factory()->ready()->create();

        Bus::assertNotDispatched(TranscodeEpisode::class);
    });

    it('does not dispatch on save when only meta changed', function (): void {
        $episode = Episode::factory()->ready()->create();

        Bus::fake([TranscodeEpisode::class]);

        $episode->update(['unlock_cost_coins' => 50]);

        Bus::assertNotDispatched(TranscodeEpisode::class);
    });
});

describe('TranscodeEpisode job — implementation type', function (): void {
    it('implements ShouldQueue (deferred execution)', function (): void {
        $episode = Episode::factory()->create([
            'status' => EpisodeStatus::Uploaded,
            'original_url' => 'https://temp.example.com/raw.mp4',
        ]);

        $job = new TranscodeEpisode($episode->id);

        expect($job)->toBeInstanceOf(ShouldQueue::class);
    });
});
