<?php

declare(strict_types=1);

namespace App\Services\Auth;

use App\Enums\UserStatus;
use App\Exceptions\AppException;
use App\Models\User;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

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
 *  - Несуществующий user — OTP всё равно отправляется (юзер создаётся при verify)
 *  - Re-request перезаписывает старый OTP (пользователь может потерять SMS)
 *  - На invalid verify код НЕ удаляется (юзер может попробовать ещё раз до TTL).
 *    Brute-force защищается rate-limit'ом на endpoint.
 *  - На successful verify код удаляется (one-time use).
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

    /**
     * Проверить код, найти-или-создать юзера, обновить last_seen_at.
     *
     * @param  string|null  $referralCode  Код приглашающего (только для нового юзера).
     *                                     Невалидный код silent-ignored.
     *
     * @throws AppException INVALID_OTP при отсутствии/несовпадении
     * @throws AppException USER_BLOCKED при существующем blocked юзере
     */
    public function verify(string $phone, string $code, ?string $referralCode = null): User
    {
        // 1. OTP в cache?
        $expected = Cache::get($this->key($phone));
        if ($expected === null || ! hash_equals((string) $expected, $code)) {
            throw new AppException(
                errorCode: 'INVALID_OTP',
                message: 'OTP is invalid or expired.',
                statusCode: 422,
            );
        }

        return DB::transaction(function () use ($phone, $referralCode): User {
            $user = User::where('phone', $phone)->lockForUpdate()->first();

            if ($user !== null) {
                // Defense in depth — также проверяется в request(), но между
                // request и verify юзер мог быть забанен модератором.
                if (! $user->status->canLogin()) {
                    throw new AppException(
                        errorCode: 'USER_BLOCKED',
                        message: 'This account is blocked. Contact support.',
                        statusCode: 422,
                    );
                }

                $user->update(['last_seen_at' => now()]);
            } else {
                $user = User::create([
                    'phone' => $phone,
                    'locale' => 'ru',
                    'country_code' => 'TJ',
                    'status' => UserStatus::Active,
                    'last_seen_at' => now(),
                    'referred_by_user_id' => $this->resolveReferrer($referralCode),
                ]);
            }

            // Удаляем OTP — one-time use.
            Cache::forget($this->key($phone));

            return $user;
        });
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

    /** Найти id приглашающего по referral_code; null если код невалиден. */
    private function resolveReferrer(?string $referralCode): ?int
    {
        if ($referralCode === null || $referralCode === '') {
            return null;
        }

        return User::where('referral_code', $referralCode)->value('id');
    }
}
