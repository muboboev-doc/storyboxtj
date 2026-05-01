<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Enums\EpisodeStatus;
use App\Models\Episode;
use App\Models\Series;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Episode>
 */
class EpisodeFactory extends Factory
{
    protected $model = Episode::class;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        return [
            'series_id' => Series::factory(),
            'number' => $this->faker->numberBetween(1, 50),
            'title' => null, // Эпизоды чаще без названия
            'synopsis' => null,
            'duration_sec' => $this->faker->numberBetween(60, 120),
            'is_free' => false,
            'unlock_cost_coins' => 30,
            'status' => EpisodeStatus::Uploaded,
            'original_url' => 'https://temp-uploads.example.com/episode-'
                .$this->faker->uuid().'.mp4',
            'published_at' => null,
        ];
    }

    /** Эпизод в готовом для воспроизведения состоянии. */
    public function ready(): static
    {
        return $this->state([
            'status' => EpisodeStatus::Ready,
            'published_at' => now(),
            'original_url' => null, // оригинал удалён после транскода
        ]);
    }

    public function transcoding(): static
    {
        return $this->state(['status' => EpisodeStatus::Transcoding]);
    }

    public function failed(): static
    {
        return $this->state(['status' => EpisodeStatus::Failed]);
    }

    public function free(): static
    {
        return $this->state(['is_free' => true, 'unlock_cost_coins' => 0]);
    }

    public function paid(int $coins = 30): static
    {
        return $this->state([
            'is_free' => false,
            'unlock_cost_coins' => $coins,
        ]);
    }

    public function forSeries(Series $series, int $number): static
    {
        return $this->state(['series_id' => $series->id, 'number' => $number]);
    }
}
