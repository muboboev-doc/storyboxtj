<?php

declare(strict_types=1);

namespace App\Services\Auth;

use App\Exceptions\AppException;

/**
 * Контракт для отправки OTP пользователю.
 *
 * Реализации:
 *  - {@see TelegramOtpSender} — основной канал (через Telegram-бот).
 *    На Phase 1.3 — заглушка-логгер. Реальная интеграция — Phase 5+.
 *  - {@see SmsOtpSender} — fallback (через Osonsms / iSMS).
 *
 * CLAUDE.md §3.3: OTP канал.
 *
 * Реализации НЕ возвращают результат — провал отправки → Exception
 * (handler смапит на 502 либо retry через очередь).
 */
interface OtpSenderInterface
{
    /**
     * Отправить OTP-код на phone.
     *
     * @param  string  $phone  E.164, например `+992901234567`
     * @param  string  $code  6-digit code
     *
     * @throws AppException при невозможности отправить
     */
    public function send(string $phone, string $code): void;
}
