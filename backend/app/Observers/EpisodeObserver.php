<?php

declare(strict_types=1);

namespace App\Observers;

use App\Enums\EpisodeStatus;
use App\Jobs\TranscodeEpisode;
use App\Models\Episode;

/**
 * Наблюдатель за моделью Episode.
 *
 * Phase 2.7:
 *   - При создании Episode со статусом Uploaded и непустым original_url —
 *     автоматически диспатчим TranscodeEpisode job. Это снимает с
 *     контент-менеджера ручную обязанность «нажать transcoding».
 *
 *   - При обновлении: если original_url только что появился (был null) ИЛИ
 *     status вручную переведён в Uploaded (например, для переторанскода) —
 *     диспатчим заново.
 *
 * Phase 4 заменит stub-job на реальный ffmpeg-пайплайн.
 */
final class EpisodeObserver
{
    public function created(Episode $episode): void
    {
        if ($this->shouldTranscode($episode)) {
            TranscodeEpisode::dispatch($episode->id);
        }
    }

    public function updated(Episode $episode): void
    {
        // Если original_url был перезалит — пере-транскодим.
        if ($episode->wasChanged('original_url') && $this->shouldTranscode($episode)) {
            TranscodeEpisode::dispatch($episode->id);
        }
    }

    private function shouldTranscode(Episode $episode): bool
    {
        return $episode->status === EpisodeStatus::Uploaded
            && ! empty($episode->original_url);
    }
}
