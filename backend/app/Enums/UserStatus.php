<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * Статус юзера. Влияет на access к контенту и /admin.
 *
 * - active        — стандартное состояние, full access
 * - blocked       — забанен модератором, не может логиниться
 * - shadow_banned — anomaly detection пометил (CLAUDE.md §9), плеер показывает заглушку,
 *                   логин работает, но контент недоступен
 * - deleted       — soft delete; запись остаётся для аудита
 */
enum UserStatus: string
{
    case Active = 'active';
    case Blocked = 'blocked';
    case ShadowBanned = 'shadow_banned';
    case Deleted = 'deleted';

    /** Может ли юзер с таким статусом логиниться. */
    public function canLogin(): bool
    {
        return $this === self::Active || $this === self::ShadowBanned;
    }

    /** Может ли юзер с таким статусом смотреть контент. */
    public function canConsumeContent(): bool
    {
        return $this === self::Active;
    }
}
