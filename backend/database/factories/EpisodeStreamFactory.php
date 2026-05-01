<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Enums\StreamQuality;
use App\Models\Episode;
use App\Models\EpisodeStream;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<EpisodeStream>
 */
class EpisodeStreamFactory extends Factory
{
    protected $model = EpisodeStream::class;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        /** @var StreamQuality $quality */
        $quality = $this->faker->randomElement(StreamQuality::cases());

        return [
            'episode_id' => Episode::factory(),
            'quality' => $quality,
            'manifest_url' => "https://cdn.example.com/episodes/{$this->faker->uuid()}/{$quality->value}/master.m3u8",
            'segment_base_url' => "https://cdn.example.com/episodes/{$this->faker->uuid()}/{$quality->value}",
            'drm_protected' => false,
            'file_size_bytes' => $this->fileSizeFor($quality),
        ];
    }

    private function fileSizeFor(StreamQuality $quality): int
    {
        return match ($quality) {
            StreamQuality::Sd240 => 5_000_000,
            StreamQuality::Sd480 => 15_000_000,
            StreamQuality::Hd720 => 35_000_000,
            StreamQuality::Hd1080 => 70_000_000,
        };
    }

    public function quality(StreamQuality $q): static
    {
        return $this->state(['quality' => $q]);
    }

    public function withDrm(): static
    {
        return $this->state(['drm_protected' => true]);
    }
}
