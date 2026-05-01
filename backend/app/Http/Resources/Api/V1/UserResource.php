<?php

declare(strict_types=1);

namespace App\Http\Resources\Api\V1;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @property User $resource
 */
final class UserResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->resource->id,
            'name' => $this->resource->name,
            'email' => $this->resource->email,
            'phone' => $this->resource->phone,
            'locale' => $this->resource->locale,
            'country_code' => $this->resource->country_code,
            'referral_code' => $this->resource->referral_code,
            'status' => $this->resource->status->value,
            'avatar_url' => $this->resource->avatar_url,
            'email_verified_at' => $this->resource->email_verified_at?->toIso8601String(),
            'created_at' => $this->resource->created_at->toIso8601String(),
            'updated_at' => $this->resource->updated_at->toIso8601String(),
        ];
    }
}
