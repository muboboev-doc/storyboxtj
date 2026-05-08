<?php

declare(strict_types=1);

namespace App\Services\Content;

use App\Models\Episode;
use App\Models\User;

/**
 * Проверка доступа юзера к эпизоду.
 *
 * Phase 2 (текущая): только free-эпизоды доступны.
 * Phase 3 (Wallet+Unlock) добавит:
 *   - VIP-подписка → доступ ко всему контенту
 *   - User\EpisodeUnlock запись → конкретный unlock через коины/рекламу
 *   - shadow_banned юзеры → ВСЕГДА false (anti-piracy, CLAUDE.md §9)
 *
 * Используется EpisodeShowController через DI.
 *
 * Возвращает sealed-DTO {@see EpisodeAccessResult}, чтобы вызывающий код
 * мог различать конкретные причины отказа (нужно для UX: «купить за коины»
 * vs «оформить VIP» vs «перешли в Telegram-бот за помощью»).
 */
final class EpisodeAccessPolicy
{
    public function check(?User $user, Episode $episode): EpisodeAccessResult
    {
        // Free эпизод — всегда доступен.
        if ($episode->is_free) {
            return EpisodeAccessResult::granted();
        }

        // Phase 3 здесь добавит: VIP / unlock проверки.
        // На Phase 2 любой не-free эпизод заблокирован.
        return EpisodeAccessResult::lockedByCost($episode);
    }
}
