<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\StreamQuality;
use Database\Factories\EpisodeStreamFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * HLS-поток эпизода в одном из качеств. Phase 2.1.
 *
 * Один Episode → несколько EpisodeStream (240p / 480p / 720p).
 * Создаются автоматически TranscodeEpisode job'ом в Phase 4.
 *
 * @property int $id
 * @property int $episode_id
 * @property StreamQuality $quality
 * @property string $manifest_url
 * @property string|null $segment_base_url
 * @property bool $drm_protected
 * @property int $file_size_bytes
 * @property-read Episode $episode
 */
class EpisodeStream extends Model
{
    /** @use HasFactory<EpisodeStreamFactory> */
    use HasFactory;

    /** @var list<string> */
    protected $fillable = [
        'episode_id',
        'quality',
        'manifest_url',
        'segment_base_url',
        'drm_protected',
        'file_size_bytes',
    ];

    protected $casts = [
        'quality' => StreamQuality::class,
        'drm_protected' => 'boolean',
        'file_size_bytes' => 'integer',
    ];

    /** @return BelongsTo<Episode, $this> */
    public function episode(): BelongsTo
    {
        return $this->belongsTo(Episode::class);
    }
}
