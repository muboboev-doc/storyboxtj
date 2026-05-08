<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Enums\SeriesStatus;
use App\Http\Resources\Api\V1\SeriesResource;
use App\Models\Series;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * `GET /api/v1/series/{id}` — детальная карточка сериала.
 *
 * Public endpoint: одинаков для гостя и authed юзера на Phase 2.
 *
 * 404 если сериал не существует или status != published — чтобы
 * draft/archived контент не «протекал» через прямой URL.
 */
final class SeriesShowController
{
    public function __invoke(Request $request, int $id): SeriesResource
    {
        $series = Series::query()
            ->where('status', SeriesStatus::Published)
            ->with(['genres', 'episodes'])
            ->find($id);

        if ($series === null) {
            throw new NotFoundHttpException('Series not found.');
        }

        return new SeriesResource($series);
    }
}
