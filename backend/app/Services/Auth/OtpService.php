<?php

declare(strict_types=1);

namespace App\Services\Auth;

use App\Exceptions\AppException;
use App\Models\User;
use Illuminate\Support\Facades\Cache;

/**
 * Сервис управления OTP-кодами.
 *
 * Storage: Cache (Redis в проде, array в тестах).
 *   key   — `otp:<phone>`
 *   value — 6-digit string
 *   TTL   — `OTP_TTL_SECONDS` (default 300)
 *
 * Контракт безопасности (CLAUDE.md §6, §8):
 *  - Cryptographic random_int — не Math.random
 *  - Blocked user — отказ; shadow_banned — продолжаем (canLogin == true)
 *  - Несуществующий user — OTP всё равно отправляется (юзер создаётся
 *    в OtpService::verify в Phase 1.5)
 *  - Re-request перезаписывает старый OTP (пользователь может потерять SMS)
 *
 * Phase 1.5 добавит:
 *  - verify(phone, code): User
 *  - rate-limit на verify (защита brute-force на код)
 */
final class OtpService
{
    public function __construct(
        private readonly OtpSenderInterface $sender,
    ) {}

    /**
     * Сгенерировать 6-digit OTP, сохранить в cache, отправить.
     *
     * @return \DateTimeInterface expires_at
     *
     * @throws AppException USER_BLOCKED если phone привязан к blocked-юзеру
     */
    public function request(string $phone): \DateTimeInterface
    {
        // Если юзер уже есть и blocked — отказ.
        $user = User::where('phone', $phone)->first();
        if ($user !== null && ! $user->status->canLogin()) {
            throw new AppException(
                errorCode: 'USER_BLOCKED',
                message: 'This account is blocked. Contact support.',
                statusCode: 422,
            );
        }

        $code = $this->generateCode();
        $ttl = (int) config('auth.otp.ttl_seconds', 300);

        Cache::put($this->key($phone), $code, $ttl);

        $this->sender->send($phone, $code);

        return now()->addSeconds($ttl);
    }

    /** Cryptographically random 6-digit code (no leading-zero stripping). */
    private function generateCode(): string
    {
        return str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    }

    private function key(string $phone): string
    {
        return "otp:{$phone}";
    }
}
