<?php

declare(strict_types=1);

namespace App\Http\Resources\Api\V1;

use App\Models\Genre;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @property Genre $resource
 */
final class GenreResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $locale = $this->resolveLocale($request);

        return [
            'id' => $this->resource->id,
            'slug' => $this->resource->slug,
            'name' => $this->resource->getTranslation('name', $locale, useFallbackLocale: true),
        ];
    }

    private function resolveLocale(Request $request): string
    {
        $supported = ['ru', 'en', 'tg', 'uz', 'kk', 'ky'];

        return $request->getPreferredLanguage($supported) ?? config('app.locale', 'ru');
    }
}
