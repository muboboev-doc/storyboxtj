<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * Стадии обработки видео-файла эпизода.
 *
 * - uploaded    — оригинал загружен в темп S3, ждёт транскодинг
 * - transcoding — FFmpeg-job в работе (Phase 4 — transcode)
 * - ready       — HLS streams готовы, episode_streams заполнены
 * - failed      — транскодинг упал, требует ручного вмешательства
 *
 * Только `ready` эпизоды показываются юзерам.
 */
enum EpisodeStatus: string
{
    case Uploaded = 'uploaded';
    case Transcoding = 'transcoding';
    case Ready = 'ready';
    case Failed = 'failed';

    public function isPlayable(): bool
    {
        return $this === self::Ready;
    }
}
