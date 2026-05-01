<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Enums\UserStatus;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    /** Кэш bcrypt-хеша 'password' — экономит ~150ms на тест. */
    protected static ?string $password = null;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'phone' => null, // OTP-юзер задаст позже через otpVerified() state
            'email_verified_at' => now(),
            'password' => static::$password ??= Hash::make('password'),
            'locale' => 'ru',
            'country_code' => 'TJ',
            'status' => UserStatus::Active,
            'last_seen_at' => now(),
            'remember_token' => Str::random(10),
        ];
    }

    /** Email не верифицирован (для тестов flow подтверждения). */
    public function unverified(): static
    {
        return $this->state(['email_verified_at' => null]);
    }

    /** Юзер созданный через phone OTP (без email). */
    public function withPhone(?string $phone = null): static
    {
        return $this->state([
            'email' => null,
            'phone' => $phone ?? fake()->unique()->e164PhoneNumber(),
            'email_verified_at' => null,
        ]);
    }

    /** Заблокированный модератором (не может логиниться). */
    public function blocked(): static
    {
        return $this->state(['status' => UserStatus::Blocked]);
    }

    /** Shadow-banned (anomaly detect, плеер показывает заглушку). */
    public function shadowBanned(): static
    {
        return $this->state(['status' => UserStatus::ShadowBanned]);
    }
}
