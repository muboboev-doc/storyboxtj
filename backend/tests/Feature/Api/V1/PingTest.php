<?php

declare(strict_types=1);

/*
 * Smoke-тест для /api/v1/ping. Проверяет, что:
 *  — эндпоинт доступен без авторизации;
 *  — статус 200;
 *  — структура JSON совпадает со схемой (status, service, version, environment, timestamp);
 *  — timestamp валиден ISO 8601.
 *
 * Это baseline-тест: должен проходить всегда. Его падение = сломалось что-то базовое
 * (роутинг, конфиг приложения, ServiceProvider'ы).
 */

it('returns 200 with expected json structure', function (): void {
    $response = $this->getJson('/api/v1/ping');

    $response
        ->assertOk()
        ->assertJson([
            'status' => 'ok',
            'service' => config('app.name'),
            'environment' => app()->environment(),
        ])
        ->assertJsonStructure([
            'status',
            'service',
            'version',
            'environment',
            'timestamp',
        ]);
});

it('returns iso8601 timestamp', function (): void {
    $response = $this->getJson('/api/v1/ping');

    $timestamp = $response->json('timestamp');

    expect($timestamp)
        ->toBeString()
        ->and(strtotime((string) $timestamp))->not->toBeFalse();
});

it('does not require authentication', function (): void {
    // Без токена — всё равно 200.
    $this->getJson('/api/v1/ping')->assertOk();
});
