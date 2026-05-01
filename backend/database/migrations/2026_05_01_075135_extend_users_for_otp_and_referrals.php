<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
 * Phase 1.1: расширение `users` для поддержки phone OTP, локализации,
 * рефералов и shadow-ban (CLAUDE.md §1, docs/tz.md §5.1).
 *
 * Изменения:
 *  - email становится nullable (есть OTP-only юзеры)
 *  - password становится nullable (тот же случай)
 *  - phone (unique, nullable) — primary identity для OTP flow
 *  - locale, country_code — локализация (CLAUDE.md §11)
 *  - referral_code (unique) — генерится при создании
 *  - referred_by_user_id (nullable FK) — кто пригласил
 *  - status (enum) — active / blocked / shadow_banned / deleted
 *  - last_seen_at — для anomaly detection (CLAUDE.md §9)
 *  - avatar_url
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            // Identity для phone-OTP flow.
            $table->string('phone', 20)->nullable()->unique()->after('email');

            // Локализация.
            $table->string('locale', 5)->default('ru')->after('phone');
            $table->string('country_code', 2)->nullable()->after('locale');

            // Рефералы.
            $table->string('referral_code', 12)->nullable()->unique()->after('country_code');
            $table->foreignId('referred_by_user_id')
                ->nullable()
                ->after('referral_code')
                ->constrained('users')
                ->nullOnDelete();

            // Статус для модерации (shadow_banned = anomaly detect, см. CLAUDE.md §9).
            $table->enum('status', ['active', 'blocked', 'shadow_banned', 'deleted'])
                ->default('active')
                ->after('referred_by_user_id');

            // Audit / anomaly.
            $table->timestamp('last_seen_at')->nullable()->after('status');
            $table->string('avatar_url', 500)->nullable()->after('last_seen_at');

            // Индекс по статусу для быстрых выборок active-юзеров.
            $table->index('status');
            $table->index('last_seen_at');
        });

        // email и password — nullable (OTP-only юзеры).
        // На MySQL 8 для смены nullable нужен doctrine/dbal или raw SQL.
        // Используем raw для совместимости с любыми версиями.
        Schema::table('users', function (Blueprint $table): void {
            $table->string('email')->nullable()->change();
            $table->string('password')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropForeign(['referred_by_user_id']);
            $table->dropIndex(['status']);
            $table->dropIndex(['last_seen_at']);

            $table->dropColumn([
                'phone',
                'locale',
                'country_code',
                'referral_code',
                'referred_by_user_id',
                'status',
                'last_seen_at',
                'avatar_url',
            ]);

            // Возвращаем email/password к not null (default Laravel).
            $table->string('email')->nullable(false)->change();
            $table->string('password')->nullable(false)->change();
        });
    }
};
