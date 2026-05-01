<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\UserStatus;
use Database\Factories\UserFactory;
use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Laravel\Sanctum\HasApiTokens;
use Spatie\Permission\Traits\HasRoles;

/**
 * @property int $id
 * @property string|null $name
 * @property string|null $email
 * @property string|null $phone
 * @property string|null $password
 * @property string $locale
 * @property string|null $country_code
 * @property string|null $referral_code
 * @property int|null $referred_by_user_id
 * @property UserStatus $status
 * @property string|null $avatar_url
 * @property Carbon|null $email_verified_at
 * @property Carbon|null $last_seen_at
 * @property Carbon $created_at
 * @property Carbon $updated_at
 * @property-read Wallet|null $wallet
 * @property-read Collection<int, UserSocialAccount> $socialAccounts
 * @property-read User|null $referrer
 * @property-read Collection<int, User> $referrals
 */
class User extends Authenticatable implements FilamentUser
{
    use HasApiTokens;

    /** @use HasFactory<UserFactory> */
    use HasFactory;

    use HasRoles;
    use Notifiable;

    /** @var list<string> */
    protected $fillable = [
        'name',
        'email',
        'phone',
        'password',
        'locale',
        'country_code',
        'referral_code',
        'referred_by_user_id',
        'status',
        'avatar_url',
        'last_seen_at',
        'email_verified_at',
    ];

    /** @var list<string> */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /** @return array<string, string> */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'last_seen_at' => 'datetime',
            'password' => 'hashed',
            'status' => UserStatus::class,
        ];
    }

    /**
     * Auto-генерация referral_code на create, если не задан.
     * Алгоритм: 8 ASCII-символов uppercase, гарантированно unique
     * (повторяем при collision — UNIQUE INDEX в БД ловит).
     */
    protected static function booted(): void
    {
        static::creating(function (User $user): void {
            if (empty($user->referral_code)) {
                $user->referral_code = self::generateReferralCode();
            }
        });
    }

    public static function generateReferralCode(): string
    {
        do {
            $code = strtoupper(Str::random(8));
        } while (self::where('referral_code', $code)->exists());

        return $code;
    }

    // ─── Relations ──────────────────────────────────────────────────────────

    /** @return HasOne<Wallet, $this> */
    public function wallet(): HasOne
    {
        return $this->hasOne(Wallet::class);
    }

    /** @return HasMany<UserSocialAccount, $this> */
    public function socialAccounts(): HasMany
    {
        return $this->hasMany(UserSocialAccount::class);
    }

    /** @return BelongsTo<User, $this> */
    public function referrer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'referred_by_user_id');
    }

    /** @return HasMany<User, $this> */
    public function referrals(): HasMany
    {
        return $this->hasMany(User::class, 'referred_by_user_id');
    }

    // ─── Filament ───────────────────────────────────────────────────────────

    /**
     * Доступ к Filament-панели.
     *
     * Только super_admin / content_manager / finance_manager / support / viewer
     * могут зайти в /admin (даже только для просмотра).
     * Конкретные права на ресурсы — через Policies + Spatie Permission в Phase 1+.
     */
    public function canAccessPanel(Panel $panel): bool
    {
        return $this->hasAnyRole([
            'super_admin',
            'content_manager',
            'finance_manager',
            'support',
            'viewer',
        ]);
    }
}
