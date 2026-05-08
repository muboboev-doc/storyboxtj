<?php

declare(strict_types=1);

namespace App\Http\Resources\Api\V1;

use App\Enums\EpisodeStatus;
use App\Models\Series;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Полное представление сериала (для /series/{id}).
 *
 * Episodes фильтруются по `status=ready` и сортируются по `number ASC`
 * прямо здесь — контроллер просто отдаёт `new SeriesResource($series)`.
 *
 * @property Series $resource
 */
final class SeriesResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $locale = $this->resolveLocale($request);

        $readyEpisodes = $this->resource->episodes
            ->where('status', EpisodeStatus::Ready)
            ->sortBy('number')
            ->values();

        return [
            'id' => $this->resource->id,
            'title' => $this->resource->getTranslation('title', $locale, useFallbackLocale: true),
            'synopsis' => $this->resource->synopsis === null
                ? null
                : $this->resource->getTranslation('synopsis', $locale, useFallbackLocale: true),
            'poster_url' => $this->resource->poster_url,
            'banner_url' => $this->resource->banner_url,
            'free_episodes_count' => (int) $this->resource->free_episodes_count,
            'total_episodes' => (int) $this->resource->total_episodes,
            'is_premium' => (bool) $this->resource->is_premium,
            'published_at' => $this->resource->published_at?->toIso8601String(),
            'genres' => GenreResource::collection($this->resource->genres),
            'episodes' => EpisodeResource::collection($readyEpisodes),
        ];
    }

    private function resolveLocale(Request $request): string
    {
        $supported = ['ru', 'en', 'tg', 'uz', 'kk', 'ky'];

        return $request->getPreferredLanguage($supported) ?? config('app.locale', 'ru');
    }
}
