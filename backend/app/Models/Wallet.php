<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\WalletFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Кошелёк коинов пользователя.
 *
 * **CLAUDE.md §6 deal-breaker:** прямые `update($coins_balance)` ЗАПРЕЩЕНЫ.
 * Любое изменение баланса — только через `App\Services\Wallet\WalletService`,
 * который оборачивает в `DB::transaction` + `LOCK FOR UPDATE` и пишет
 * `wallet_transactions` (Phase 3+).
 *
 * @property int $id
 * @property int $user_id
 * @property int $coins_balance
 * @property int $bonus_coins_balance
 * @property int $total_earned
 * @property int $total_spent
 * @property Carbon $created_at
 * @property Carbon $updated_at
 * @property-read User $user
 * @property-read int $total_balance
 */
class Wallet extends Model
{
    /** @use HasFactory<WalletFactory> */
    use HasFactory;

    protected $fillable = [
        'user_id',
        'coins_balance',
        'bonus_coins_balance',
        'total_earned',
        'total_spent',
    ];

    protected $casts = [
        'coins_balance' => 'integer',
        'bonus_coins_balance' => 'integer',
        'total_earned' => 'integer',
        'total_spent' => 'integer',
    ];

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** Общий баланс (платные + бонусные). Read-only. */
    public function getTotalBalanceAttribute(): int
    {
        return $this->coins_balance + $this->bonus_coins_balance;
    }
}
