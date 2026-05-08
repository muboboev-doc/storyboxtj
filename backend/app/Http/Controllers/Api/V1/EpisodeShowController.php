<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Enums\EpisodeStatus;
use App\Enums\SeriesStatus;
use App\Http\Resources\Api\V1\EpisodeShowResource;
use App\Models\Episode;
use App\Services\Content\EpisodeAccessPolicy;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * `GET /api/v1/episodes/{id}` — детальная инфа эпизода + HLS streams.
 *
 * Доступ: проверяется `EpisodeAccessPolicy::check($user, $episode)`.
 *  - Free → всегда 200
 *  - Paid → 403 EPISODE_LOCKED (Phase 3 добавит VIP / unlock)
 *
 * 404 если:
 *  - эпизод не существует
 *  - status != ready (uploaded / transcoding / failed — внутренние состояния)
 *  - series.status != published (защита от просачивания через прямой URL)
 */
final class EpisodeShowController
{
    public function __construct(
        private readonly EpisodeAccessPolicy $policy,
    ) {}

    public function __invoke(Request $request, int $id): EpisodeShowResource|JsonResponse
    {
        $episode = Episode::query()
            ->where('status', EpisodeStatus::Ready)
            ->whereHas('series', function ($query): void {
                $query->where('status', SeriesStatus::Published);
            })
            ->with(['series', 'streams'])
            ->find($id);

        if ($episode === null) {
            throw new NotFoundHttpException('Episode not found.');
        }

        $access = $this->policy->check($request->user(), $episode);

        if (! $access->granted) {
            return response()->json([
                'error' => [
                    'code' => $access->reasonCode,
                    'message' => $access->reasonMessage,
                    'context' => $access->context,
                ],
            ], 403);
        }

        return new EpisodeShowResource($episode);
    }
}
