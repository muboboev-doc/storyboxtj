<?php

declare(strict_types=1);

namespace App\Observers;

use App\Models\Series;
use App\Services\Content\HomeService;

/**
 * Сбрасывает home-кэш при любых изменениях Series.
 *
 * Сценарии:
 *  - Контент-менеджер опубликовал новый сериал → home invalidated
 *  - Изменён position / title / poster_url → home invalidated
 *  - Сериал deleted → home invalidated
 *
 * Гранулированная инвалидация (только конкретная локаль) — Phase 7+,
 * когда введём более сложный кэш с pattern-based delete.
 */
final class SeriesObserver
{
    public function __construct(private readonly HomeService $home) {}

    public function saved(Series $series): void
    {
        $this->home->flushAllLocales();
    }

    public function deleted(Series $series): void
    {
        $this->home->flushAllLocales();
    }
}
