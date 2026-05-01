<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * Качество HLS-потока. Один эпизод имеет несколько streams (240p / 480p / 720p).
 * 1080p — фаза 2 (требует Widevine L1 + больше storage).
 *
 * См. CLAUDE.md §9 (anti-piracy) и docs/tz.md §5.13.
 */
enum StreamQuality: string
{
    case Sd240 = '240p';
    case Sd480 = '480p';
    case Hd720 = '720p';
    case Hd1080 = '1080p';

    public function bitrateKbps(): int
    {
        return match ($this) {
            self::Sd240 => 400,
            self::Sd480 => 1000,
            self::Hd720 => 2500,
            self::Hd1080 => 5000,
        };
    }
}
