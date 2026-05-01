<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\EpisodeStatus;
use Database\Factories\EpisodeFactory;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;
use Spatie\Translatable\HasTranslations;

/**
 * Эпизод сериала. Phase 2.1.
 *
 * Translatable: `title`, `synopsis`. Phase 4 добавит `episode_streams` через
 * TranscodeEpisode job; Phase 8 — `episode_keys` для DRM.
 *
 * @property int $id
 * @property int $series_id
 * @property int $number
 * @property array<string, string>|string|null $title
 * @property array<string, string>|string|null $synopsis
 * @property int $duration_sec
 * @property bool $is_free
 * @property int $unlock_cost_coins
 * @property EpisodeStatus $status
 * @property string|null $original_url
 * @property Carbon|null $published_at
 * @property-read Series $series
 * @property-read Collection<int, EpisodeStream> $streams
 */
class Episode extends Model
{
    /** @use HasFactory<EpisodeFactory> */
    use HasFactory;

    use HasTranslations;

    /** @var list<string> */
    protected $fillable = [
        'series_id',
        'number',
        'title',
        'synopsis',
        'duration_sec',
        'is_free',
        'unlock_cost_coins',
        'status',
        'original_url',
        'published_at',
    ];

    /** @var list<string> */
    public array $translatable = ['title', 'synopsis'];

    protected $casts = [
        'is_free' => 'boolean',
        'duration_sec' => 'integer',
        'unlock_cost_coins' => 'integer',
        'number' => 'integer',
        'status' => EpisodeStatus::class,
        'published_at' => 'datetime',
    ];

    /** @return BelongsTo<Series, $this> */
    public function series(): BelongsTo
    {
        return $this->belongsTo(Series::class);
    }

    /** @return HasMany<EpisodeStream, $this> */
    public function streams(): HasMany
    {
        return $this->hasMany(EpisodeStream::class);
    }

    public function isPlayable(): bool
    {
        return $this->status === EpisodeStatus::Ready;
    }
}
