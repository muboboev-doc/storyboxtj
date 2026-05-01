<?php

declare(strict_types=1);

namespace App\Services\Auth;

use Illuminate\Support\Facades\Log;

/**
 * Phase 1.3 stub: логгер вместо реального Telegram-бота.
 *
 * Реальная интеграция (Phase 5+, ретеншн):
 *  1. Бот регистрируется и получает chat_id юзера через deep-link
 *     `https://t.me/storybox_bot?start=<phone-token>`
 *  2. Backend связывает phone ↔ chat_id в `device_tokens` таблице
 *  3. send() POST'ит на api.telegram.org/bot.../sendMessage
 *
 * Сейчас логирует код в Laravel-лог (info-level, попадает в Sentry breadcrumbs).
 * На staging/dev этого достаточно — разработчик копирует код из лога.
 */
final class TelegramOtpSender implements OtpSenderInterface
{
    public function send(string $phone, string $code): void
    {
        Log::info('[OTP] Telegram stub: would send code', [
            'phone' => $phone,
            'code' => $code,
            'note' => 'Replace with real Telegram bot integration in Phase 5+.',
        ]);
    }
}
