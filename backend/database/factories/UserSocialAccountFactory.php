<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Enums\SocialProvider;
use App\Models\User;
use App\Models\UserSocialAccount;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<UserSocialAccount>
 */
class UserSocialAccountFactory extends Factory
{
    protected $model = UserSocialAccount::class;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'provider' => $this->faker->randomElement(SocialProvider::cases()),
            'provider_uid' => $this->faker->uuid(),
        ];
    }

    public function google(): static
    {
        return $this->state(['provider' => SocialProvider::Google]);
    }

    public function apple(): static
    {
        return $this->state(['provider' => SocialProvider::Apple]);
    }

    public function facebook(): static
    {
        return $this->state(['provider' => SocialProvider::Facebook]);
    }
}
