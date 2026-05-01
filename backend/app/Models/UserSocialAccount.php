<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\SocialProvider;
use Database\Factories\UserSocialAccountFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Привязка user'а к OAuth-провайдеру (Google/Apple/Facebook).
 *
 * Логика поиска: при логине через социалку ищем по `(provider, provider_uid)`.
 * Если найдено — логин в существующего; если нет — создаём нового user'а
 * + сразу wallet (через UserObserver в Phase 1.5).
 *
 * @property int $id
 * @property int $user_id
 * @property SocialProvider $provider
 * @property string $provider_uid
 * @property Carbon $created_at
 * @property Carbon $updated_at
 * @property-read User $user
 */
class UserSocialAccount extends Model
{
    /** @use HasFactory<UserSocialAccountFactory> */
    use HasFactory;

    protected $fillable = [
        'user_id',
        'provider',
        'provider_uid',
    ];

    protected $casts = [
        'provider' => SocialProvider::class,
    ];

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
