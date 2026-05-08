<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Services\Content\HomeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * `GET /api/v1/home` — главный экран.
 *
 * Public endpoint: гость и authed получают одинаковую структуру (на Phase 2).
 * `continue_watching` пустой; в Phase 5+ заполнится из `user_watch_history`
 * для authed юзеров.
 *
 * Locale: берём из Accept-Language header (если есть), иначе app default.
 */
final class HomeController
{
    public function __construct(
        private readonly HomeService $home,
    ) {}

    public function __invoke(Request $request): JsonResponse
    {
        $locale = $this->resolveLocale($request);

        return response()->json($this->home->payload($locale));
    }

    private function resolveLocale(Request $request): string
    {
        $supported = ['ru', 'en', 'tg', 'uz', 'kk', 'ky'];

        $preferred = $request->getPreferredLanguage($supported);

        return $preferred ?? config('app.locale', 'ru');
    }
}
