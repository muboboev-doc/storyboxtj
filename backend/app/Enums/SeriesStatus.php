<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * Жизненный цикл сериала.
 *
 * - draft     — создан в админке, ещё редактируется, в каталоге не виден
 * - published — виден на /home, в /discover, эпизоды доступны
 * - archived  — выведен из каталога (старая лицензия и т.д.), но юзеры с
 *               unlock'ами и истории просмотров продолжают доступ
 */
enum SeriesStatus: string
{
    case Draft = 'draft';
    case Published = 'published';
    case Archived = 'archived';

    public function isVisible(): bool
    {
        return $this === self::Published;
    }
}
