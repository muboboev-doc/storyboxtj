<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Enums\SeriesStatus;
use App\Models\Series;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Series>
 */
class SeriesFactory extends Factory
{
    protected $model = Series::class;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        $title = ucwords((string) $this->faker->words(3, asText: true));

        return [
            'title' => [
                'ru' => "{$title} (RU)",
                'en' => $title,
                'tg' => "{$title} (TG)",
                'uz' => "{$title} (UZ)",
                'kk' => "{$title} (KK)",
                'ky' => "{$title} (KY)",
            ],
            'synopsis' => [
                'ru' => $this->faker->paragraph(),
                'en' => $this->faker->paragraph(),
            ],
            'poster_url' => $this->faker->imageUrl(540, 960, 'series-poster'),
            'banner_url' => $this->faker->imageUrl(1920, 1080, 'series-banner'),
            'free_episodes_count' => 3,
            'total_episodes' => 0,
            'status' => SeriesStatus::Draft,
            'is_premium' => false,
            'position' => $this->faker->numberBetween(0, 100),
            'published_at' => null,
        ];
    }

    public function published(): static
    {
        return $this->state([
            'status' => SeriesStatus::Published,
            'published_at' => now(),
        ]);
    }

    public function archived(): static
    {
        return $this->state(['status' => SeriesStatus::Archived]);
    }

    public function premium(): static
    {
        return $this->state(['is_premium' => true]);
    }
}
