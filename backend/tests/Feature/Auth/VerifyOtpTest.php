<?php

declare(strict_types=1);

/*
 * Phase 1.4 (TDD red): спецификация POST /api/v1/auth/otp/verify.
 * Phase 1.5 — реализация.
 *
 * Контракт:
 *   POST /api/v1/auth/otp/verify
 *   Body: { phone: "+992...", code: "123456", referral_code?: "ABC12345" }
 *   →
 *   200 { user: {...}, wallet: {...}, token: "1|...", token_type: "Bearer" }
 *   422 { error: { code: "INVALID_OTP", ... } }       — нет в cache / не совпал
 *   422 { error: { code: "USER_BLOCKED", ... } }      — defense in depth
 *   422 — validation (phone/code format)
 *
 * Бизнес-правила:
 *  - Поиск user по phone → если есть, логиним; если нет, создаём (status=active, locale=ru, country_code=TJ)
 *  - UserObserver авто-создаёт wallet (Phase 1.1)
 *  - OTP удаляется из cache после успешного verify (one-time use)
 *  - Невалидный код → OTP остаётся (юзер может попробовать снова до TTL)
 *  - Brute-force защита через rate-limit на endpoint
 *  - referral_code: если валиден → set referred_by_user_id; если нет → silent ignore (не блокируем регистрацию)
 *  - last_seen_at обновляется
 *  - Sanctum personal-access-token issued, можно сразу обратиться к /me
 */

use App\Enums\UserStatus;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\RateLimiter;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    RateLimiter::clear('auth-otp');
    Cache::flush();
});

/** Хелпер: записать OTP в cache (имитация предыдущего /auth/otp/request). */
function seedOtp(string $phone, string $code = '123456', int $ttl = 300): void
{
    Cache::put("otp:{$phone}", $code, $ttl);
}

describe('POST /api/v1/auth/otp/verify — happy path (new user)', function (): void {
    it('creates a new user with phone and returns Sanctum token', function (): void {
        seedOtp('+992901111111', '123456');

        $response = $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+992901111111',
            'code' => '123456',
        ]);

        $response
            ->assertOk()
            ->assertJsonStructure([
                'user' => ['id', 'phone', 'locale', 'country_code', 'status', 'created_at'],
                'wallet' => ['coins_balance', 'bonus_coins_balance', 'total_balance'],
                'token',
                'token_type',
            ])
            ->assertJsonPath('user.phone', '+992901111111')
            ->assertJsonPath('user.status', 'active')
            ->assertJsonPath('user.locale', 'ru')
            ->assertJsonPath('user.country_code', 'TJ')
            ->assertJsonPath('wallet.coins_balance', 0)
            ->assertJsonPath('token_type', 'Bearer');

        $token = $response->json('token');
        expect($token)->toBeString()->and($token)->not->toBeEmpty();

        // User действительно создан в БД.
        $user = User::where('phone', '+992901111111')->firstOrFail();
        expect($user->status)->toBe(UserStatus::Active)
            ->and($user->wallet)->not->toBeNull();  // через UserObserver
    });

    it('issued token actually works for /api/v1/me', function (): void {
        seedOtp('+992901111111');

        $token = $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+992901111111',
            'code' => '123456',
        ])->json('token');

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('phone', '+992901111111');
    });

    it('deletes OTP after successful verify (one-time use)', function (): void {
        seedOtp('+992901111111');

        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+992901111111',
            'code' => '123456',
        ])->assertOk();

        expect(Cache::get('otp:+992901111111'))->toBeNull();

        // Re-use should fail.
        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+992901111111',
            'code' => '123456',
        ])
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'INVALID_OTP');
    });
});

describe('POST /api/v1/auth/otp/verify — happy path (existing user)', function (): void {
    it('logs in existing user and updates last_seen_at', function (): void {
        $user = User::factory()
            ->withPhone('+992902222222')
            ->create(['last_seen_at' => now()->subDays(7)]);

        $oldLastSeen = $user->last_seen_at;

        seedOtp('+992902222222');

        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+992902222222',
            'code' => '123456',
        ])
            ->assertOk()
            ->assertJsonPath('user.id', $user->id);

        $user->refresh();
        expect($user->last_seen_at->isAfter($oldLastSeen))->toBeTrue();
    });

    it('does not duplicate user on repeat OTP flow', function (): void {
        User::factory()->withPhone('+992902222222')->create();

        seedOtp('+992902222222');
        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+992902222222',
            'code' => '123456',
        ])->assertOk();

        expect(User::where('phone', '+992902222222')->count())->toBe(1);
    });
});

describe('POST /api/v1/auth/otp/verify — invalid code', function (): void {
    it('rejects wrong code with INVALID_OTP and keeps cache intact', function (): void {
        seedOtp('+992901111111', '123456');

        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+992901111111',
            'code' => '000000',
        ])
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'INVALID_OTP');

        // OTP остался — юзер может попробовать снова.
        expect(Cache::get('otp:+992901111111'))->toBe('123456');

        // User НЕ создан.
        expect(User::where('phone', '+992901111111')->exists())->toBeFalse();
    });

    it('rejects code when no OTP was requested', function (): void {
        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+992901111111',
            'code' => '123456',
        ])
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'INVALID_OTP');
    });

    it('rejects when phone in cache mismatches request phone', function (): void {
        seedOtp('+992901111111', '123456');

        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+992909999999',  // другой phone
            'code' => '123456',
        ])
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'INVALID_OTP');
    });
});

describe('POST /api/v1/auth/otp/verify — validation', function (): void {
    it('rejects missing phone or code with 422', function (): void {
        $this->postJson('/api/v1/auth/otp/verify', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['phone', 'code']);
    });

    it('rejects non-E.164 phone', function (): void {
        $this->postJson('/api/v1/auth/otp/verify', ['phone' => '992...', 'code' => '123456'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['phone']);
    });

    it('rejects code that is not 6 digits', function (): void {
        $invalidCodes = ['12345', '1234567', 'abcdef', '12 456', '123-56'];

        foreach ($invalidCodes as $code) {
            $this->postJson('/api/v1/auth/otp/verify', [
                'phone' => '+992901111111',
                'code' => $code,
            ])
                ->assertStatus(422)
                ->assertJsonValidationErrors(['code']);
        }
    });
});

describe('POST /api/v1/auth/otp/verify — security', function (): void {
    it('rejects blocked existing user with USER_BLOCKED', function (): void {
        User::factory()->withPhone('+992903333333')->blocked()->create();

        seedOtp('+992903333333');

        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+992903333333',
            'code' => '123456',
        ])
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'USER_BLOCKED');
    });

    it('allows shadow_banned user to verify and get token', function (): void {
        User::factory()->withPhone('+992904444444')->shadowBanned()->create();

        seedOtp('+992904444444');

        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+992904444444',
            'code' => '123456',
        ])
            ->assertOk()
            ->assertJsonPath('user.status', 'shadow_banned');
    });
});

describe('POST /api/v1/auth/otp/verify — referrals', function (): void {
    it('attaches referrer when valid referral_code provided', function (): void {
        $referrer = User::factory()->create();

        seedOtp('+992905555555');

        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+992905555555',
            'code' => '123456',
            'referral_code' => $referrer->referral_code,
        ])->assertOk();

        $newUser = User::where('phone', '+992905555555')->firstOrFail();
        expect($newUser->referred_by_user_id)->toBe($referrer->id);
    });

    it('silently ignores invalid referral_code (does not block registration)', function (): void {
        seedOtp('+992905555555');

        $response = $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+992905555555',
            'code' => '123456',
            'referral_code' => 'NOTVALID',  // не существует
        ]);

        $response->assertOk();

        $newUser = User::where('phone', '+992905555555')->firstOrFail();
        expect($newUser->referred_by_user_id)->toBeNull();
    });

    it('does not change referrer for existing user', function (): void {
        $existing = User::factory()->withPhone('+992905555555')->create();
        $newReferrer = User::factory()->create();

        seedOtp('+992905555555');

        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+992905555555',
            'code' => '123456',
            'referral_code' => $newReferrer->referral_code,
        ])->assertOk();

        $existing->refresh();
        expect($existing->referred_by_user_id)->toBeNull();
    });
});
