<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Enums\EpisodeStatus;
use App\Enums\StreamQuality;
use App\Models\Episode;
use App\Models\EpisodeStream;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

/**
 * Транскодинг оригинального видео эпизода в HLS-варианты (240/480/720/1080p).
 *
 * Phase 2.7: STUB-реализация — создаёт записи EpisodeStream с фейковыми
 * manifest_url и помечает Episode как Ready. Это позволяет:
 *  - демонстрировать end-to-end пайплайн «загрузил оригинал → плеер играет»
 *  - писать остальной API-контракт (/api/v1/episodes/{id}) без блока на ffmpeg
 *
 * Phase 4 заменит handle() на реальный pipeline:
 *  - download original_url → /tmp
 *  - ffmpeg -i → 4 ABR-варианта + master.m3u8
 *  - upload в Bunny Stream / S3
 *  - заполнение manifest_url, segment_base_url, file_size_bytes реальными значениями
 *  - DRM keys (Phase 8 — anti-piracy)
 *
 * Идемпотентность: на старте удаляем существующие streams для этого episode_id,
 * затем создаём заново. Безопасно при повторных запусках.
 */
final class TranscodeEpisode implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    /** Stub префикс CDN-пути. Phase 4 — реальный bunny-stream URL. */
    private const FAKE_CDN_PREFIX = 'https://stub-cdn.storybox.tj/episodes';

    /** Имитация размеров файлов в зависимости от качества. */
    private const FILE_SIZE_BY_QUALITY = [
        '240p' => 5_000_000,
        '480p' => 15_000_000,
        '720p' => 35_000_000,
        '1080p' => 70_000_000,
    ];

    public int $tries = 3;

    public int $backoff = 30;

    public function __construct(public readonly int $episodeId) {}

    public function handle(): void
    {
        $episode = Episode::query()->find($this->episodeId);

        if ($episode === null) {
            Log::warning('TranscodeEpisode: episode not found', ['id' => $this->episodeId]);

            return;
        }

        DB::transaction(function () use ($episode): void {
            // 1. Помечаем работу как стартовавшую.
            $episode->status = EpisodeStatus::Transcoding;
            $episode->save();

            // 2. Идемпотентность: удаляем старые streams (если повторный запуск).
            EpisodeStream::query()
                ->where('episode_id', $episode->id)
                ->delete();

            // 3. Создаём 4 ABR-варианта.
            $bucket = Str::uuid()->toString();
            foreach (StreamQuality::cases() as $quality) {
                EpisodeStream::query()->create([
                    'episode_id' => $episode->id,
                    'quality' => $quality,
                    'manifest_url' => sprintf(
                        '%s/%s/%s/master.m3u8',
                        self::FAKE_CDN_PREFIX,
                        $bucket,
                        $quality->value,
                    ),
                    'segment_base_url' => sprintf(
                        '%s/%s/%s',
                        self::FAKE_CDN_PREFIX,
                        $bucket,
                        $quality->value,
                    ),
                    'drm_protected' => false,
                    'file_size_bytes' => self::FILE_SIZE_BY_QUALITY[$quality->value],
                ]);
            }

            // 4. Готов к воспроизведению.
            $episode->status = EpisodeStatus::Ready;
            $episode->published_at = $episode->published_at ?? now();
            $episode->save();

            // 5. Пересчёт total_episodes у сериала (only ready-эпизоды).
            $series = $episode->series;
            $series->total_episodes = $series->episodes()
                ->where('status', EpisodeStatus::Ready)
                ->count();
            $series->saveQuietly();
        });
    }

    public function failed(?Throwable $e): void
    {
        Log::error('TranscodeEpisode failed', [
            'episode_id' => $this->episodeId,
            'error' => $e?->getMessage(),
        ]);

        Episode::query()
            ->where('id', $this->episodeId)
            ->update(['status' => EpisodeStatus::Failed]);
    }
}
