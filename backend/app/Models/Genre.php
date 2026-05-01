<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\GenreFactory;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Spatie\Translatable\HasTranslations;

/**
 * Жанр контента (драма, романтика, детектив, ...). Phase 2.1.
 *
 * Многоязычное поле `name` — JSON через Spatie HasTranslations.
 * Чтение в текущей локали: `$genre->name`. Конкретный язык:
 * `$genre->getTranslation('name', 'en')`.
 *
 * @property int $id
 * @property array<string, string>|string $name
 * @property string $slug
 * @property int $position
 * @property bool $is_active
 * @property-read Collection<int, Series> $series
 */
class Genre extends Model
{
    /** @use HasFactory<GenreFactory> */
    use HasFactory;

    use HasTranslations;

    /** @var list<string> */
    protected $fillable = [
        'name',
        'slug',
        'position',
        'is_active',
    ];

    /** @var list<string> */
    public array $translatable = ['name'];

    protected $casts = [
        'is_active' => 'boolean',
        'position' => 'integer',
    ];

    /** @return BelongsToMany<Series, $this> */
    public function series(): BelongsToMany
    {
        return $this->belongsToMany(Series::class, 'series_genres');
    }
}
