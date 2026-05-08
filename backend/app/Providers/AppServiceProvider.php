<?php

declare(strict_types=1);

namespace App\Providers;

use App\Models\Series;
use App\Models\User;
use App\Observers\SeriesObserver;
use App\Observers\UserObserver;
use App\Services\Auth\OtpSenderInterface;
use App\Services\Auth\TelegramOtpSender;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // Phase 1.3: дефолтный OTP-отправитель — Telegram (stub-логгер).
        // В тестах перебиваем через $this->mock(OtpSenderInterface::class).
        $this->app->bind(OtpSenderInterface::class, TelegramOtpSender::class);
    }

    public function boot(): void
    {
        // Phase 2.4: API Resources не оборачиваются в {"data":...}. Контракт
        // /api/v1/* — плоский JSON. Совместимость со старыми Resource'ами
        // (UserResource, WalletResource) сохраняется — они и так используются
        // через `response()->json(['user' => new UserResource(...)])`.
        JsonResource::withoutWrapping();

        // Phase 1.1: auto-create wallet on user creation.
        User::observe(UserObserver::class);

        // Phase 2.3: invalidate home cache при изменении Series.
        Series::observe(SeriesObserver::class);

        // Phase 1.3: rate-limit для /api/v1/auth/otp/* (CLAUDE.md §8.2 — 10 rpm на IP).
        RateLimiter::for('auth-otp', function (Request $request): Limit {
            $perMinute = (int) config('auth.otp.rate_limit_per_minute', 10);

            return Limit::perMinute($perMinute)->by($request->ip());
        });
    }
}
