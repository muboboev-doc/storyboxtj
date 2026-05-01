<?php

declare(strict_types=1);

namespace App\Console\Commands;

use Illuminate\Console\Command;

/**
 * Отправляет тестовое событие в Sentry. Используется для verification что DSN
 * правильно настроен — после `php artisan sentry:test` в Sentry UI должно
 * появиться событие.
 *
 * Если DSN пустой — команда сообщает об этом и завершается с кодом 0
 * (это валидное состояние для local-окружения).
 */
final class SentryTestCommand extends Command
{
    protected $signature = 'sentry:test';

    protected $description = 'Send a test exception to Sentry to verify DSN configuration.';

    public function handle(): int
    {
        $dsn = config('sentry.dsn');

        if (empty($dsn)) {
            $this->warn('SENTRY_LARAVEL_DSN is empty — Sentry SDK is in no-op mode.');
            $this->line('Set SENTRY_LARAVEL_DSN in .env to enable error reporting.');
            $this->line('See docs/setup-monitoring.md for instructions.');

            return self::SUCCESS;
        }

        $this->info("Sending test event to Sentry (DSN: {$this->maskDsn($dsn)})...");

        try {
            throw new \RuntimeException(
                'Test exception from `php artisan sentry:test` at '.now()->toIso8601String()
            );
        } catch (\Throwable $e) {
            $eventId = \Sentry\captureException($e);

            if ($eventId !== null) {
                $this->info("✓ Event sent to Sentry: {$eventId}");
                $this->line('Check your Sentry project dashboard.');

                return self::SUCCESS;
            }

            $this->error('✗ Failed to send event. Check Sentry SDK logs.');

            return self::FAILURE;
        }
    }

    /** Маскирует токен в DSN для безопасного вывода. */
    private function maskDsn(string $dsn): string
    {
        return preg_replace('#://([^@]+)@#', '://***@', $dsn) ?? $dsn;
    }
}
