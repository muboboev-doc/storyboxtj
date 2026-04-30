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
        $this->call([
            RolesAndAdminSeeder::class,
            // В Phase 0.9 добавится TestContentSeeder (5 жанров, 20 сериалов и т.д.).
            // В Phase 4 — BankProviderSeeder.
        ]);
    }
}
