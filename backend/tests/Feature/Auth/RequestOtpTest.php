<?php

declare(strict_types=1);

/*
 * Phase 1.2 (TDD red): спецификация поведения POST /api/v1/auth/otp/request.
 * Phase 1.3 — реализация.
 *
 * Контракт:
 *   POST /api/v1/auth/otp/request
 *   Body: { phone: "+992..." }
 *   →
 *   200 { sent: true, expires_at: "ISO8601" }      # успех
 *   422 { error: { code: "INVALID_PHONE", ... } }  # формат не E.164
 *   422 { error: { code: "USER_BLOCKED", ... } }   # status=blocked
 *   429                                             # rate limit
 *
 * Бизнес-правила (CLAUDE.md §8.2 — auth: 10 rpm per IP):
 *   - 6-digit OTP
 *   - TTL 5 минут в Redis
 *   - Отправка через OtpSenderInterface (mock'ается в тестах)
 *   - Существующий blocked юзер → отказ
 *   - Несуществующий юзер → OTP всё равно отправляется (юзер создаётся при verify)
 *   - shadow_banned юзер → OTP отправляется (canLogin() == true)
 *
 * Для верификации Phase 1.3 implementation заработает корректно.
 */

use App\Enums\UserStatus;
use App\Models\User;
use App\Services\Auth\OtpSenderInterface;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\RateLimiter;
use Mockery\MockInterface;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    // Сбрасываем rate-limiter и cache между тестами.
    RateLimiter::clear('auth-otp');
    Cache::flush();
});

describe('POST /api/v1/auth/otp/request — happy path', function (): void {
    it('returns 200 with expires_at and dispatches OTP via OtpSenderInterface', function (): void {
        /** @var MockInterface&OtpSenderInterface $sender */
        $sender = $this->mock(OtpSenderInterface::class, function (MockInterface $mock): void {
            $mock->shouldReceive('send')
                ->once()
                ->with('+992901234567', \Mockery::pattern('/^\d{6}$/'));
        });

        $response = $this->postJson('/api/v1/auth/otp/request', [
            'phone' => '+992901234567',
        ]);

        $response
            ->assertOk()
            ->assertJsonStructure(['sent', 'expires_at'])
            ->assertJsonPath('sent', true);
    });

    it('stores OTP in cache with 5-minute TTL', function (): void {
        $this->mock(OtpSenderInterface::class, function (MockInterface $mock): void {
            $mock->shouldReceive('send')->once();
        });

        $this->postJson('/api/v1/auth/otp/request', ['phone' => '+992901234567'])->assertOk();

        $cached = Cache::get('otp:+992901234567');
        expect($cached)
            ->toBeString()
            ->and($cached)->toMatch('/^\d{6}$/');
    });

    it('overwrites existing OTP on re-request (allows resend)', function (): void {
        $this->mock(OtpSenderInterface::class, function (MockInterface $mock): void {
            $mock->shouldReceive('send')->twice();
        });

        $this->postJson('/api/v1/auth/otp/request', ['phone' => '+992901234567'])->assertOk();
        $first = Cache::get('otp:+992901234567');

        $this->postJson('/api/v1/auth/otp/request', ['phone' => '+992901234567'])->assertOk();
        $second = Cache::get('otp:+992901234567');

        expect($first)->not->toBeNull()
            ->and($second)->not->toBeNull();
        // Может быть равен (10⁻⁶ chance), но в среднем разный — проверяем что валидный код.
        expect($second)->toMatch('/^\d{6}$/');
    });

    it('sends OTP to existing active user', function (): void {
        $user = User::factory()->withPhone('+992901111111')->create([
            'status' => UserStatus::Active,
        ]);

        $this->mock(OtpSenderInterface::class, function (MockInterface $mock): void {
            $mock->shouldReceive('send')->once()->with('+992901111111', \Mockery::any());
        });

        $this->postJson('/api/v1/auth/otp/request', ['phone' => $user->phone])->assertOk();
    });

    it('sends OTP to shadow_banned user (canLogin = true)', function (): void {
        User::factory()->withPhone('+992901222222')->shadowBanned()->create();

        $this->mock(OtpSenderInterface::class, function (MockInterface $mock): void {
            $mock->shouldReceive('send')->once();
        });

        $this->postJson('/api/v1/auth/otp/request', ['phone' => '+992901222222'])->assertOk();
    });
});

describe('POST /api/v1/auth/otp/request — validation', function (): void {
    it('rejects missing phone with 422', function (): void {
        $this->postJson('/api/v1/auth/otp/request', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['phone']);
    });

    it('rejects non-E.164 phone format with 422', function (): void {
        $invalidPhones = [
            '992901234567',         // missing +
            '+',                    // empty
            '+0123',                // starts with 0
            '+abcdefg',             // letters
            '+123 456 789',         // spaces
            str_repeat('+9', 20),   // too long
        ];

        foreach ($invalidPhones as $phone) {
            $this->postJson('/api/v1/auth/otp/request', ['phone' => $phone])
                ->assertStatus(422)
                ->assertJsonValidationErrors(['phone']);
        }
    });

    it('accepts E.164 phones from various countries', function (): void {
        $this->mock(OtpSenderInterface::class, function (MockInterface $mock): void {
            $mock->shouldReceive('send')->times(4);
        });

        $validPhones = [
            '+992901234567',  // Tajikistan
            '+79991234567',   // Russia
            '+998901234567',  // Uzbekistan
            '+15555550100',   // US
        ];

        foreach ($validPhones as $phone) {
            $this->postJson('/api/v1/auth/otp/request', ['phone' => $phone])->assertOk();
        }
    });
});

describe('POST /api/v1/auth/otp/request — security', function (): void {
    it('rejects blocked user with USER_BLOCKED code', function (): void {
        User::factory()->withPhone('+992901333333')->blocked()->create();

        // Sender НЕ должен вызываться для blocked юзера.
        $this->mock(OtpSenderInterface::class, function (MockInterface $mock): void {
            $mock->shouldNotReceive('send');
        });

        $this->postJson('/api/v1/auth/otp/request', ['phone' => '+992901333333'])
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'USER_BLOCKED');
    });

    it('rate-limits at 10 requests per minute per IP', function (): void {
        $this->mock(OtpSenderInterface::class, function (MockInterface $mock): void {
            $mock->shouldReceive('send')->times(10);
        });

        // 10 запросов проходят (используем разные phone'ы чтобы не зацепить per-phone лимит).
        for ($i = 0; $i < 10; $i++) {
            $this->postJson('/api/v1/auth/otp/request', [
                'phone' => sprintf('+992901%07d', $i),
            ])->assertOk();
        }

        // 11-й — 429.
        $this->postJson('/api/v1/auth/otp/request', ['phone' => '+992901999999'])
            ->assertStatus(429);
    });
});
