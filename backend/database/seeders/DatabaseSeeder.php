<?php

declare(strict_types=1);

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Главный сидер. Запускает остальные в правильном порядке.
     *
     * Запуск: `php artisan db:seed` или `migrate:fresh --seed`.
     */
    public function run(): void
    {
        // Базовые сидеры (роли + super_admin) — нужны на ВСЕХ окружениях,
        // включая production (минимально: super_admin для первого логина).
        $this->call([
            RolesAndAdminSeeder::class,
        ]);

        // Тестовые юзеры — только на не-prod окружениях.
        // CLAUDE.md §7 deal-breaker: не плодим тест-аккаунты на prod.
        if (app()->environment('local', 'testing', 'staging')) {
            $this->call([
                TestUsersSeeder::class,
            ]);

            // Phase 0.9 placeholder. Позже подключатся:
            //   TestContentSeeder      (Phase 2: жанры, сериалы, эпизоды)
            //   BankProviderSeeder     (Phase 6: 3 банка в test mode)
            //   IapProductSeeder       (Phase 5: SKU для IAP sandbox)
        }
    }
}
