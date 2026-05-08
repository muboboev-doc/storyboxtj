<?php

declare(strict_types=1);

namespace App\Http\Resources\Api\V1;

use App\Models\EpisodeStream;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @property EpisodeStream $resource
 */
final class EpisodeStreamResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'quality' => $this->resource->quality->value,
            'manifest_url' => $this->resource->manifest_url,
            'drm_protected' => (bool) $this->resource->drm_protected,
        ];
    }
}
