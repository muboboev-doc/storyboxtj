<?php

declare(strict_types=1);

/*
 * Phase 2.1: тесты на миграции, relations, translatable поля для контентных моделей.
 *
 * Проверяем:
 *  - Genre/Series/Episode/EpisodeStream factories создают валидные записи
 *  - HasTranslations работает (read с current locale, write JSON)
 *  - Series belongsToMany Genre via series_genres
 *  - Series hasMany Episode (ordered by number)
 *  - Episode belongsTo Series, hasMany EpisodeStream
 *  - Уникальность (series.number, episode_streams quality)
 *  - Cascade-delete (delete series → episodes → streams)
 *  - Enum casts (SeriesStatus, EpisodeStatus, StreamQuality)
 */

use App\Enums\EpisodeStatus;
use App\Enums\SeriesStatus;
use App\Enums\StreamQuality;
use App\Models\Episode;
use App\Models\EpisodeStream;
use App\Models\Genre;
use App\Models\Series;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

describe('Genre', function (): void {
    it('factory creates a valid genre', function (): void {
        $genre = Genre::factory()->create();

        expect($genre->id)->toBeInt()
            ->and($genre->slug)->toBeString()
            ->and($genre->is_active)->toBeTrue();
    });

    it('stores translations in JSON column', function (): void {
        $genre = Genre::factory()->drama()->create();

        expect($genre->getTranslation('name', 'ru'))->toBe('Драма')
            ->and($genre->getTranslation('name', 'en'))->toBe('Drama')
            ->and($genre->getTranslation('name', 'tg'))->toBe('Драма');
    });

    it('reads name in current app locale', function (): void {
        $genre = Genre::factory()->romance()->create();

        app()->setLocale('en');
        expect($genre->name)->toBe('Romance');

        app()->setLocale('ru');
        expect($genre->name)->toBe('Романтика');

        app()->setLocale('tg');
        expect($genre->name)->toBe('Ишқ');
    });

    it('slug is unique', function (): void {
        Genre::factory()->create(['slug' => 'taken']);

        expect(fn () => Genre::factory()->create(['slug' => 'taken']))
            ->toThrow(QueryException::class);
    });
});

describe('Series', function (): void {
    it('factory creates draft series with empty episodes count', function (): void {
        $series = Series::factory()->create();

        expect($series->status)->toBe(SeriesStatus::Draft)
            ->and($series->status->isVisible())->toBeFalse()
            ->and($series->total_episodes)->toBe(0)
            ->and($series->free_episodes_count)->toBe(3);
    });

    it('published state sets status and published_at', function (): void {
        $series = Series::factory()->published()->create();

        expect($series->status)->toBe(SeriesStatus::Published)
            ->and($series->isPublished())->toBeTrue()
            ->and($series->published_at)->not->toBeNull();
    });

    it('translatable title roundtrips', function (): void {
        $series = Series::factory()->create([
            'title' => ['ru' => 'Любовь в Душанбе', 'en' => 'Love in Dushanbe'],
        ]);

        expect($series->getTranslation('title', 'ru'))->toBe('Любовь в Душанбе')
            ->and($series->getTranslation('title', 'en'))->toBe('Love in Dushanbe');
    });

    it('attaches genres via pivot', function (): void {
        $series = Series::factory()->create();
        $drama = Genre::factory()->drama()->create();
        $romance = Genre::factory()->romance()->create();

        $series->genres()->attach([$drama->id, $romance->id]);
        $series->refresh();

        expect($series->genres)->toHaveCount(2)
            ->and($series->genres->pluck('slug')->all())
            ->toContain('drama')
            ->toContain('romance');

        // Reverse — genre.series тоже работает.
        expect($drama->series)->toHaveCount(1)
            ->and($drama->series->first()->id)->toBe($series->id);
    });

    it('has many episodes ordered by number', function (): void {
        $series = Series::factory()->create();
        Episode::factory()->forSeries($series, 3)->create();
        Episode::factory()->forSeries($series, 1)->create();
        Episode::factory()->forSeries($series, 2)->create();

        $series->refresh();

        expect($series->episodes->pluck('number')->all())->toBe([1, 2, 3]);
    });
});

describe('Episode', function (): void {
    it('factory creates uploaded episode with no original_url removed', function (): void {
        $episode = Episode::factory()->create();

        expect($episode->status)->toBe(EpisodeStatus::Uploaded)
            ->and($episode->status->isPlayable())->toBeFalse()
            ->and($episode->original_url)->toBeString();
    });

    it('ready state sets status and clears original_url', function (): void {
        $episode = Episode::factory()->ready()->create();

        expect($episode->status)->toBe(EpisodeStatus::Ready)
            ->and($episode->status->isPlayable())->toBeTrue()
            ->and($episode->isPlayable())->toBeTrue()
            ->and($episode->original_url)->toBeNull();
    });

    it('free state sets is_free=true and unlock_cost=0', function (): void {
        $episode = Episode::factory()->free()->create();

        expect($episode->is_free)->toBeTrue()
            ->and($episode->unlock_cost_coins)->toBe(0);
    });

    it('paid state lets you set custom unlock cost', function (): void {
        $episode = Episode::factory()->paid(coins: 50)->create();

        expect($episode->is_free)->toBeFalse()
            ->and($episode->unlock_cost_coins)->toBe(50);
    });

    it('series_id + number must be unique within a series', function (): void {
        $series = Series::factory()->create();
        Episode::factory()->forSeries($series, 1)->create();

        expect(
            fn () => Episode::factory()->forSeries($series, 1)->create()
        )->toThrow(QueryException::class);
    });

    it('belongs to series', function (): void {
        $series = Series::factory()->create();
        $episode = Episode::factory()->forSeries($series, 1)->create();

        expect($episode->series->id)->toBe($series->id);
    });
});

describe('EpisodeStream', function (): void {
    it('factory creates a stream with quality and URLs', function (): void {
        $stream = EpisodeStream::factory()->create();

        expect($stream->quality)->toBeInstanceOf(StreamQuality::class)
            ->and($stream->manifest_url)->toContain('master.m3u8')
            ->and($stream->drm_protected)->toBeFalse();
    });

    it('episode_id + quality must be unique', function (): void {
        $episode = Episode::factory()->create();
        EpisodeStream::factory()
            ->quality(StreamQuality::Hd720)
            ->create(['episode_id' => $episode->id]);

        expect(
            fn () => EpisodeStream::factory()
                ->quality(StreamQuality::Hd720)
                ->create(['episode_id' => $episode->id])
        )->toThrow(QueryException::class);
    });

    it('different qualities for same episode are allowed', function (): void {
        $episode = Episode::factory()->create();

        EpisodeStream::factory()->quality(StreamQuality::Sd240)->create(['episode_id' => $episode->id]);
        EpisodeStream::factory()->quality(StreamQuality::Sd480)->create(['episode_id' => $episode->id]);
        EpisodeStream::factory()->quality(StreamQuality::Hd720)->create(['episode_id' => $episode->id]);

        $episode->refresh();
        expect($episode->streams)->toHaveCount(3);
    });

    it('belongs to episode', function (): void {
        $episode = Episode::factory()->create();
        $stream = EpisodeStream::factory()->create(['episode_id' => $episode->id]);

        expect($stream->episode->id)->toBe($episode->id);
    });
});

describe('Cascade delete', function (): void {
    it('deleting series cascades to episodes and streams', function (): void {
        $series = Series::factory()->create();
        $episode = Episode::factory()->forSeries($series, 1)->create();
        $stream = EpisodeStream::factory()->create(['episode_id' => $episode->id]);

        $series->delete();

        expect(Episode::find($episode->id))->toBeNull()
            ->and(EpisodeStream::find($stream->id))->toBeNull();
    });

    it('deleting series detaches genres but does not delete them', function (): void {
        $series = Series::factory()->create();
        $genre = Genre::factory()->create();
        $series->genres()->attach($genre);

        $series->delete();

        expect(Genre::find($genre->id))->not->toBeNull();
    });
});

describe('Enum business rules', function (): void {
    it('SeriesStatus.isVisible only true for Published', function (): void {
        expect(SeriesStatus::Draft->isVisible())->toBeFalse()
            ->and(SeriesStatus::Published->isVisible())->toBeTrue()
            ->and(SeriesStatus::Archived->isVisible())->toBeFalse();
    });

    it('EpisodeStatus.isPlayable only true for Ready', function (): void {
        expect(EpisodeStatus::Uploaded->isPlayable())->toBeFalse()
            ->and(EpisodeStatus::Transcoding->isPlayable())->toBeFalse()
            ->and(EpisodeStatus::Ready->isPlayable())->toBeTrue()
            ->and(EpisodeStatus::Failed->isPlayable())->toBeFalse();
    });

    it('StreamQuality.bitrateKbps returns expected values', function (): void {
        expect(StreamQuality::Sd240->bitrateKbps())->toBe(400)
            ->and(StreamQuality::Hd720->bitrateKbps())->toBe(2500)
            ->and(StreamQuality::Hd1080->bitrateKbps())->toBe(5000);
    });
});
