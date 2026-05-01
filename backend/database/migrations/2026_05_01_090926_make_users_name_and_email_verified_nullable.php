<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
 * Phase 1.5: для phone-OTP юзеров `name` должен быть nullable
 * (имя заполняется позже через profile screen).
 *
 * docs/tz.md §5.1 определяет name как nullable, но дефолтная Laravel
 * миграция users делает его NOT NULL — фиксим здесь.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->string('name')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->string('name')->nullable(false)->change();
        });
    }
};
