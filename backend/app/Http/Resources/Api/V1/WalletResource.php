<?php

declare(strict_types=1);

namespace App\Http\Resources\Api\V1;

use App\Models\Wallet;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @property Wallet $resource
 */
final class WalletResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'coins_balance' => $this->resource->coins_balance,
            'bonus_coins_balance' => $this->resource->bonus_coins_balance,
            'total_balance' => $this->resource->total_balance,
        ];
    }
}
