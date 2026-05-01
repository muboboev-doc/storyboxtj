<?php

declare(strict_types=1);

use App\Http\Controllers\Api\V1\AuthController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Все мобильные API-маршруты живут под префиксом /api/v1/*.
| Префикс /api добавляется автоматически Laravel'овым apiPrefix.
| Версионирование (v1) — через явную группу в этом файле.
|
| Sanctum: middleware 'auth:sanctum' применяется к защищённым роутам.
*/

Route::prefix('v1')->group(function (): void {
    /*
    |----------------------------------------------------------------------
    | Системные / Healthcheck
    |----------------------------------------------------------------------
    */
    Route::get('/ping', function () {
        return response()->json([
            'status' => 'ok',
            'service' => config('app.name', 'StoryBox'),
            'version' => '0.0.1',
            'environment' => app()->environment(),
            'timestamp' => now()->toIso8601String(),
        ]);
    })->name('api.v1.ping');

    /*
    |----------------------------------------------------------------------
    | Auth (Phase 1) — phone OTP flow + social login
    |----------------------------------------------------------------------
    */
    Route::prefix('auth/otp')
        ->middleware('throttle:auth-otp')
        ->group(function (): void {
            Route::post('request', [AuthController::class, 'requestOtp'])
                ->name('api.v1.auth.otp.request');
            // Phase 1.5: Route::post('verify', [AuthController::class, 'verifyOtp']);
        });

    /*
    |----------------------------------------------------------------------
    | Защищённые роуты (требуют Sanctum-токен)
    |----------------------------------------------------------------------
    */
    Route::middleware('auth:sanctum')->group(function (): void {
        Route::get('/me', fn (Request $request) => $request->user())->name('api.v1.me');
    });
});
