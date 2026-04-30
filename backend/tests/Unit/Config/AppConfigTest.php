<?php

declare(strict_types=1);

/*
 * Sanity-чек на критичные поля config'а.
 * Низкий уровень — просто чтобы Unit testsuite не был пустой и
 * Pest не падал с error code 2 на CI.
 */

it('app config has expected name', function (): void {
    expect(config('app.name'))
        ->toBeString()
        ->and(config('app.name'))->not->toBeEmpty();
});

it('app config has timezone set', function (): void {
    expect(config('app.timezone'))
        ->toBeString()
        ->and(config('app.timezone'))->not->toBeEmpty();
});

it('database default connection is configured', function (): void {
    $default = config('database.default');
    expect($default)->toBeString();

    $connections = config('database.connections');
    expect($connections)->toBeArray()
        ->and($connections)->toHaveKey($default);
});
