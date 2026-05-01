<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
 * Phase 1.1: wallet — кошелёк коинов пользователя.
 * Один wallet = один user (1-1 relation).
 *
 * Точная баланс-таблица (`wallet_transactions`) добавится в Phase 3
 * (Wallet + Unlock Vertical Slice). Сейчас храним только текущий баланс
 * для быстрого чтения; детальная история будет в transactions.
 *
 * CLAUDE.md §6 deal-breaker: любая модификация коинов проходит через
 * `WalletService::credit/debit` с DB::transaction + LOCK FOR UPDATE.
 *
 * docs/tz.md §5.3.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wallets', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')
                ->unique()
                ->constrained('users')
                ->cascadeOnDelete();

            // Главный баланс (платные коины).
            $table->unsignedBigInteger('coins_balance')->default(0);

            // Бонусные коины (рефералы, daily check-in, реклама).
            // Расходуются прежде чем coins_balance.
            $table->unsignedBigInteger('bonus_coins_balance')->default(0);

            // Аналитика lifetime.
            $table->unsignedBigInteger('total_earned')->default(0);
            $table->unsignedBigInteger('total_spent')->default(0);

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wallets');
    }
};
