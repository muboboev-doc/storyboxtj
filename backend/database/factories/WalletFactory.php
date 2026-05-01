<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\User;
use App\Models\Wallet;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Wallet>
 */
class WalletFactory extends Factory
{
    protected $model = Wallet::class;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'coins_balance' => 0,
            'bonus_coins_balance' => 0,
            'total_earned' => 0,
            'total_spent' => 0,
        ];
    }

    /** Привязать к существующему юзеру. */
    public function forUser(User $user): static
    {
        return $this->state(['user_id' => $user->id]);
    }

    /** С заданным балансом. */
    public function withBalance(int $coins, int $bonus = 0): static
    {
        return $this->state([
            'coins_balance' => $coins,
            'bonus_coins_balance' => $bonus,
            'total_earned' => $coins + $bonus,
        ]);
    }
}
