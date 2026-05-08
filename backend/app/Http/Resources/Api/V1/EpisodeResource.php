<?php

declare(strict_types=1);

namespace App\Http\Resources\Api\V1;

use App\Models\Episode;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Краткое представление эпизода (для списка в SeriesShowResource).
 *
 * **Не включает streams** — для playback используется EpisodeShowResource.
 *
 * @property Episode $resource
 */
final class EpisodeResource extends JsonResource
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
        ];
    }

    private function resolveLocale(Request $request): string
    {
        $supported = ['ru', 'en', 'tg', 'uz', 'kk', 'ky'];

        return $request->getPreferredLanguage($supported) ?? config('app.locale', 'ru');
    }
}
