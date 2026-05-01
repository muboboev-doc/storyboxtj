<?php

declare(strict_types=1);

/*
 * Phase 0.6: Sentry config sanity-чек.
 *
 * Гарантируем что:
 *  - config/sentry.php загружается без ошибок
 *  - SDK не падает при пустом DSN (graceful no-op)
 *  - Команда `sentry:test` не падает при пустом DSN, печатает warning
 */

use Illuminate\Auth\AuthenticationException;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Validation\ValidationException;

it('sentry config loads without errors', function (): void {
    $config = config('sentry');

    expect($config)->toBeArray()
        ->and($config)->toHaveKey('dsn')
        ->and($config)->toHaveKey('environment')
        ->and($config)->toHaveKey('breadcrumbs')
        ->and($config['send_default_pii'])->toBeFalse();
});

it('captures exception silently when DSN is empty', function (): void {
    config(['sentry.dsn' => null]);

    // Должно не упасть и не зависнуть.
    \Sentry\captureException(new RuntimeException('Test exception (no DSN)'));

    expect(true)->toBeTrue();
});

it('sentry:test command exits 0 with empty DSN', function (): void {
    config(['sentry.dsn' => '']);

    $exitCode = Artisan::call('sentry:test');
    $output = Artisan::output();

    expect($exitCode)->toBe(0)
        ->and($output)->toContain('no-op mode');
});

it('ignores AuthenticationException by default', function (): void {
    $ignored = config('sentry.ignore_exceptions');

    expect($ignored)->toContain(AuthenticationException::class)
        ->and($ignored)->toContain(ValidationException::class);
});
