<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
 * Phase 1.1: связь user'а с внешними OAuth-провайдерами.
 *
 * Поддерживаемые провайдеры:
 *  - google  (через Socialite)
 *  - apple   (Sign in with Apple, iOS требование)
 *  - facebook
 *
 * Один user может иметь несколько привязок (login через Google + Apple).
 * Уникальность: (provider, provider_uid) — один Google-аккаунт = один наш user.
 *
 * docs/tz.md §5.2.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_social_accounts', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')
                ->constrained('users')
                ->cascadeOnDelete();

            $table->enum('provider', ['google', 'apple', 'facebook']);
            $table->string('provider_uid', 191);

            $table->timestamps();

            // Один внешний аккаунт = один наш user.
            $table->unique(['provider', 'provider_uid']);

            // Быстрая выборка всех привязок юзера.
            $table->index('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_social_accounts');
    }
};
