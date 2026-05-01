<?php

declare(strict_types=1);

namespace App\Observers;

use App\Models\User;
use App\Models\Wallet;

/**
 * Каждый user должен иметь wallet (1:1). Observer создаёт его сразу
 * после создания user'а — это позволяет вызывающему коду НЕ помнить
 * про wallet creation в auth flow / seeders.
 *
 * Если wallet уже существует (например, в тесте через factory()->forUser()),
 * Observer пропускает (idempotent).
 */
final class UserObserver
{
    public function created(User $user): void
    {
        // Прямой DB-чек вместо `$user->wallet === null` — последний кэширует
        // null в relations, и последующий `$user->wallet->update(...)` падает.
        $exists = Wallet::where('user_id', $user->id)->exists();

        if (! $exists) {
            $wallet = Wallet::create([
                'user_id' => $user->id,
                'coins_balance' => 0,
                'bonus_coins_balance' => 0,
            ]);

            // Устанавливаем relation в in-memory модели — чтобы вызывающий код,
            // который сразу обращается к `$user->wallet`, не делал лишний SELECT.
            $user->setRelation('wallet', $wallet);
        }
    }
}
