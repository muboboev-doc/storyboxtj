<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Genre;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Genre>
 */
class GenreFactory extends Factory
{
    protected $model = Genre::class;

    private static int $sequence = 0;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        $slug = $this->faker->unique()->slug(2).'-'.++self::$sequence;
        $base = ucfirst((string) $this->faker->words(asText: true));

        return [
            'name' => [
                'ru' => $base.' (RU)',
                'en' => $base,
                'tg' => $base.' (TG)',
                'uz' => $base.' (UZ)',
                'kk' => $base.' (KK)',
                'ky' => $base.' (KY)',
            ],
            'slug' => Str::slug($slug),
            'position' => $this->faker->numberBetween(0, 100),
            'is_active' => true,
        ];
    }

    public function inactive(): static
    {
        return $this->state(['is_active' => false]);
    }

    /** Готовые жанры с известными именами. */
    public function drama(): static
    {
        return $this->state([
            'name' => [
                'ru' => 'Драма',
                'en' => 'Drama',
                'tg' => 'Драма',
                'uz' => 'Drama',
                'kk' => 'Драма',
                'ky' => 'Драма',
            ],
            'slug' => 'drama',
        ]);
    }

    public function romance(): static
    {
        return $this->state([
            'name' => [
                'ru' => 'Романтика',
                'en' => 'Romance',
                'tg' => 'Ишқ',
                'uz' => 'Romantika',
                'kk' => 'Романтика',
                'ky' => 'Романтика',
            ],
            'slug' => 'romance',
        ]);
    }
}
