<?php

declare(strict_types=1);

namespace App\Http\Resources\Api\V1;

use App\Models\Episode;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Полное представление эпизода для playback (`GET /episodes/{id}`).
 *
 * Включает streams (HLS manifest URLs). Этот resource выдаётся ТОЛЬКО когда
 * `EpisodeAccessPolicy::canAccess($user, $episode)` пропустил.
 *
 * @property Episode $resource
 */
final class EpisodeShowResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $locale = $this->resolveLocale($request);

        return [
            'id' => $this->resource->id,
            'number' => (int) $this->resource->number,
            'title' => $this->resource->title === null
                ? null
                : $this->resource->getTranslation('title', $locale, useFallbackLocale: true),
            'synopsis' => $this->resource->synopsis === null
                ? null
                : $this->resource->getTranslation('synopsis', $locale, useFallbackLocale: true),
            'duration_sec' => (int) $this->resource->duration_sec,
            'is_free' => (bool) $this->resource->is_free,
            'unlock_cost_coins' => (int) $this->resource->unlock_cost_coins,
            'published_at' => $this->resource->published_at?->toIso8601String(),
            'series' => [
                'id' => $this->resource->series->id,
                'title' => $this->resource->series->getTranslation('title', $locale, useFallbackLocale: true),
                'poster_url' => $this->resource->series->poster_url,
            ],
            'streams' => EpisodeStreamResource::collection($this->resource->streams),
        ];
    }

    private function resolveLocale(Request $request): string
    {
        $supported = ['ru', 'en', 'tg', 'uz', 'kk', 'ky'];

        return $request->getPreferredLanguage($supported) ?? config('app.locale', 'ru');
    }
}
