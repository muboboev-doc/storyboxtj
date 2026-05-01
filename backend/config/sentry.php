<?php

declare(strict_types=1);
use Illuminate\Auth\AuthenticationException;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\MethodNotAllowedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/*
 * Sentry конфиг для Laravel.
 *
 * DSN читается из SENTRY_LARAVEL_DSN. Если пусто (default) — Sentry SDK
 * автоматически отключает себя, exceptions/breadcrumbs никуда не уходят.
 * Это позволяет приложению работать локально без учётки на sentry.io.
 *
 * Настройка для prod: см. docs/setup-monitoring.md
 *
 * Полный список опций: https://docs.sentry.io/platforms/php/guides/laravel/configuration/options/
 */

return [
    'dsn' => env('SENTRY_LARAVEL_DSN'),

    // Окружение для группировки событий в Sentry UI.
    'environment' => env('SENTRY_ENVIRONMENT', env('APP_ENV', 'production')),

    // Версия релиза (для source maps и release tracking).
    // CI выставит через `sentry-cli releases new ...`.
    'release' => env('SENTRY_RELEASE'),

    // Sample rate: 1.0 = всё, 0.1 = 10%. На prod снизим до 0.2 — экономим квоту.
    'traces_sample_rate' => env('SENTRY_TRACES_SAMPLE_RATE', 1.0) === null
        ? null
        : (float) env('SENTRY_TRACES_SAMPLE_RATE', 1.0),

    'profiles_sample_rate' => env('SENTRY_PROFILES_SAMPLE_RATE', 0.0) === null
        ? null
        : (float) env('SENTRY_PROFILES_SAMPLE_RATE', 0.0),

    // PII (telephone, email, etc.) — не шлём по умолчанию (CLAUDE.md §11).
    // В Phase 1+ можно включить выборочно через scrubbing.
    'send_default_pii' => false,

    // Игнорируемые exceptions (не отправляются в Sentry).
    'ignore_exceptions' => [
        AuthenticationException::class,
        ValidationException::class,
        NotFoundHttpException::class,
        MethodNotAllowedHttpException::class,
    ],

    // Breadcrumbs settings — что записываем в trail перед каждой ошибкой.
    'breadcrumbs' => [
        'logs' => true,         // Log::info() etc.
        'sql_queries' => true,  // Eloquent / DB queries
        'sql_bindings' => false, // bindings (PII risk!) — не шлём
        'queue_info' => true,
        'command_info' => true,
        'http_client_requests' => true, // outgoing Guzzle to banks/IAP
    ],

    'tracing' => [
        'queue_jobs' => true,
        'queue_job_transactions' => env('SENTRY_TRACE_QUEUE_ENABLED', false),
        'sql_queries' => true,
        'sql_origin' => true,
        'sql_origin_threshold_ms' => 100,
        'views' => true,
        'http_client_requests' => true,
        'redis_commands' => env('SENTRY_TRACE_REDIS_COMMANDS', false),
    ],
];
