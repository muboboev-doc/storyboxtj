<?php

declare(strict_types=1);

namespace App\Services\Content;

use App\Models\Episode;

/**
 * Результат `EpisodeAccessPolicy::check()`.
 *
 * `granted=true` → стрим доступен.
 * `granted=false` → 403 в контроллере с error.code = $reasonCode.
 *
 * Поле `context` идёт в JSON (например, `unlock_cost_coins` чтобы клиент
 * мог сразу показать кнопку «Разблокировать за N коинов»).
 */
final class EpisodeAccessResult
{
    /**
     * @param  array<string, mixed>  $context
     */
    private function __construct(
        public readonly bool $granted,
        public readonly ?string $reasonCode = null,
        public readonly ?string $reasonMessage = null,
        public readonly array $context = [],
    ) {}

    public static function granted(): self
    {
        return new self(granted: true);
    }

    public static function lockedByCost(Episode $episode): self
    {
        return new self(
            granted: false,
            reasonCode: 'EPISODE_LOCKED',
            reasonMessage: 'This episode requires unlock.',
            context: [
                'unlock_cost_coins' => (int) $episode->unlock_cost_coins,
            ],
        );
    }
}
