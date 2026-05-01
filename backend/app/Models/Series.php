<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\SeriesStatus;
use Database\Factories\SeriesFactory;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;
use Spatie\Translatable\HasTranslations;

/**
 * Сериал (вертикальные драм-эпизоды). Phase 2.1.
 *
 * Translatable поля: `title`, `synopsis`. CLAUDE.md §11.
 *
 * @property int $id
 * @property array<string, string>|string $title
 * @property array<string, string>|string|null $synopsis
 * @property string|null $poster_url
 * @property string|null $banner_url
 * @property int $free_episodes_count
 * @property int $total_episodes
 * @property SeriesStatus $status
 * @property bool $is_premium
 * @property int $position
 * @property Carbon|null $published_at
 * @property-read Collection<int, Episode> $episodes
 * @property-read Collection<int, Genre> $genres
 */
class Series extends Model
{
    /** @use HasFactory<SeriesFactory> */
    use HasFactory;

    use HasTranslations;

    protected $table = 'series';

    /** @var list<string> */
    protected $fillable = [
        'title',
        'synopsis',
        'poster_url',
        'banner_url',
        'free_episodes_count',
        'total_episodes',
        'status',
        'is_premium',
        'position',
        'published_at',
    ];

    /** @var list<string> */
    public array $translatable = ['title', 'synopsis'];

    protected $casts = [
        'is_premium' => 'boolean',
        'free_episodes_count' => 'integer',
        'total_episodes' => 'integer',
        'position' => 'integer',
        'status' => SeriesStatus::class,
        'published_at' => 'datetime',
    ];

    /** @return HasMany<Episode, $this> */
    public function episodes(): HasMany
    {
        return $this->hasMany(Episode::class)->orderBy('number');
    }

    /** @return BelongsToMany<Genre, $this> */
    public function genres(): BelongsToMany
    {
        return $this->belongsToMany(Genre::class, 'series_genres');
    }

    public function isPublished(): bool
    {
        return $this->status === SeriesStatus::Published;
    }
}
