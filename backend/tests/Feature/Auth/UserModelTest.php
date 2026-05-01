<?php

declare(strict_types=1);

/*
 * Phase 1.1: тесты на миграции, relations и observer для User/Wallet/UserSocialAccount.
 *
 * Проверяем:
 *  - User::factory() создаёт юзера
 *  - UserObserver авто-создаёт wallet при User::create()
 *  - referral_code генерится автоматически (8 символов uppercase, unique)
 *  - status каст в UserStatus enum
 *  - user.wallet relation работает
 *  - user.socialAccounts relation работает
 *  - user.referrer / user.referrals relations
 *  - phone unique constraint
 *  - email теперь nullable (для OTP-only юзеров)
 */

use App\Enums\SocialProvider;
use App\Enums\UserStatus;
use App\Models\User;
use App\Models\UserSocialAccount;
use App\Models\Wallet;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

describe('User factory + UserObserver', function (): void {
    it('factory creates a user with valid defaults', function (): void {
        $user = User::factory()->create();

        expect($user->id)->toBeInt()
            ->and($user->name)->toBeString()
            ->and($user->email)->toBeString()
            ->and($user->locale)->toBe('ru')
            ->and($user->country_code)->toBe('TJ')
            ->and($user->status)->toBe(UserStatus::Active);
    });

    it('automatically creates a wallet for every new user', function (): void {
        $user = User::factory()->create();
        $user->refresh();

        expect($user->wallet)->not->toBeNull()
            ->and($user->wallet)->toBeInstanceOf(Wallet::class)
            ->and($user->wallet->coins_balance)->toBe(0)
            ->and($user->wallet->bonus_coins_balance)->toBe(0);
    });

    it('does not create a duplicate wallet if one exists', function (): void {
        $user = User::factory()->create();
        $existing = $user->wallet;

        // Trigger another save — observer should NOT create another.
        $user->update(['name' => 'Updated Name']);
        $user->refresh();

        expect(Wallet::where('user_id', $user->id)->count())->toBe(1)
            ->and($user->wallet->id)->toBe($existing->id);
    });

    it('auto-generates a unique 8-char uppercase referral_code', function (): void {
        $user = User::factory()->create();

        expect($user->referral_code)
            ->toBeString()
            ->and(strlen($user->referral_code))->toBe(8)
            ->and($user->referral_code)->toMatch('/^[A-Z0-9]{8}$/');
    });

    it('creates unique referral codes for many users', function (): void {
        $codes = User::factory()->count(20)->create()->pluck('referral_code')->toArray();

        expect($codes)->toHaveCount(20)
            ->and(array_unique($codes))->toHaveCount(20);
    });
});

describe('User casts', function (): void {
    it('casts status to UserStatus enum', function (): void {
        $user = User::factory()->create(['status' => 'shadow_banned']);
        $user->refresh();

        expect($user->status)->toBe(UserStatus::ShadowBanned);
    });

    it('hashes password on assignment', function (): void {
        $user = User::factory()->create(['password' => 'plain-text-secret']);

        expect($user->password)->not->toBe('plain-text-secret')
            ->and(Hash::check('plain-text-secret', $user->password))->toBeTrue();
    });
});

describe('User states (factory)', function (): void {
    it('withPhone() creates an OTP-only user without email', function (): void {
        $user = User::factory()->withPhone('+992901234567')->create();

        expect($user->phone)->toBe('+992901234567')
            ->and($user->email)->toBeNull()
            ->and($user->email_verified_at)->toBeNull();
    });

    it('blocked() user has UserStatus::Blocked', function (): void {
        $user = User::factory()->blocked()->create();

        expect($user->status)->toBe(UserStatus::Blocked)
            ->and($user->status->canLogin())->toBeFalse();
    });

    it('shadowBanned() user can still login but cannot consume content', function (): void {
        $user = User::factory()->shadowBanned()->create();

        expect($user->status)->toBe(UserStatus::ShadowBanned)
            ->and($user->status->canLogin())->toBeTrue()
            ->and($user->status->canConsumeContent())->toBeFalse();
    });
});

describe('User constraints', function (): void {
    it('phone must be unique', function (): void {
        User::factory()->withPhone('+992111111111')->create();

        expect(fn () => User::factory()->withPhone('+992111111111')->create())
            ->toThrow(QueryException::class);
    });

    it('referral_code must be unique', function (): void {
        $user = User::factory()->create();

        expect(fn () => User::factory()->create(['referral_code' => $user->referral_code]))
            ->toThrow(QueryException::class);
    });
});

describe('Relations', function (): void {
    it('user.wallet returns the wallet', function (): void {
        $user = User::factory()->create();

        expect($user->wallet)->toBeInstanceOf(Wallet::class)
            ->and($user->wallet->user_id)->toBe($user->id);
    });

    it('wallet.user returns the owner', function (): void {
        $user = User::factory()->create();
        $wallet = $user->wallet;

        expect($wallet->user)->toBeInstanceOf(User::class)
            ->and($wallet->user->id)->toBe($user->id);
    });

    it('wallet.total_balance sums regular + bonus', function (): void {
        $user = User::factory()->create();
        $user->wallet->update(['coins_balance' => 100, 'bonus_coins_balance' => 30]);
        $user->refresh();

        expect($user->wallet->total_balance)->toBe(130);
    });

    it('user.socialAccounts returns linked OAuth accounts', function (): void {
        $user = User::factory()->create();
        UserSocialAccount::factory()->google()->create([
            'user_id' => $user->id,
            'provider_uid' => 'google_uid_1',
        ]);
        UserSocialAccount::factory()->apple()->create([
            'user_id' => $user->id,
            'provider_uid' => 'apple_uid_1',
        ]);
        $user->refresh();

        expect($user->socialAccounts)->toHaveCount(2)
            ->and($user->socialAccounts->pluck('provider')->all())
            ->toContain(SocialProvider::Google)
            ->toContain(SocialProvider::Apple);
    });

    it('social account (provider, provider_uid) must be unique', function (): void {
        UserSocialAccount::factory()->google()->create(['provider_uid' => 'shared-uid']);

        expect(fn () => UserSocialAccount::factory()->google()->create(['provider_uid' => 'shared-uid']))
            ->toThrow(QueryException::class);
    });

    it('user.referrer + user.referrals work for invite chains', function (): void {
        $referrer = User::factory()->create();
        $invited = User::factory()->create(['referred_by_user_id' => $referrer->id]);

        expect($invited->referrer->id)->toBe($referrer->id)
            ->and($referrer->referrals)->toHaveCount(1)
            ->and($referrer->referrals->first()->id)->toBe($invited->id);
    });
});

describe('UserStatus enum', function (): void {
    it('canLogin reflects business rules', function (): void {
        expect(UserStatus::Active->canLogin())->toBeTrue()
            ->and(UserStatus::ShadowBanned->canLogin())->toBeTrue()
            ->and(UserStatus::Blocked->canLogin())->toBeFalse()
            ->and(UserStatus::Deleted->canLogin())->toBeFalse();
    });

    it('canConsumeContent only true for Active', function (): void {
        expect(UserStatus::Active->canConsumeContent())->toBeTrue()
            ->and(UserStatus::ShadowBanned->canConsumeContent())->toBeFalse()
            ->and(UserStatus::Blocked->canConsumeContent())->toBeFalse()
            ->and(UserStatus::Deleted->canConsumeContent())->toBeFalse();
    });
});
