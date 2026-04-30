<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

/**
 * Создаёт 5 базовых ролей (CLAUDE.md §8.1) и одного super_admin'а
 * для разработки. На staging/prod — пароль должен быть изменён через
 * админ-форму после первого логина.
 */
final class RolesAndAdminSeeder extends Seeder
{
    /** Список ролей с описаниями. Используется в Phase 1+ для UI. */
    private const ROLES = [
        'super_admin' => 'Полный доступ ко всему. Только разработчики/основатели.',
        'content_manager' => 'CRUD контента (сериалы, эпизоды, жанры) + переводы.',
        'finance_manager' => 'Биллинг, банки, IAP, reconciliation, refund.',
        'support' => 'Чтение пользователей, ответы на тикеты, ручные начисления.',
        'viewer' => 'Только чтение дашбордов и аналитики.',
    ];

    /** Дефолтный super_admin для локальной разработки. */
    private const SUPER_ADMIN_EMAIL = 'admin@storybox.tj';

    private const SUPER_ADMIN_PASSWORD = 'password';

    private const SUPER_ADMIN_NAME = 'Super Admin';

    public function run(): void
    {
        // Сбрасываем кэш ролей Spatie перед сидерами.
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        // 1. Роли.
        foreach (array_keys(self::ROLES) as $roleName) {
            Role::firstOrCreate([
                'name' => $roleName,
                'guard_name' => 'web',
            ]);
        }

        $this->command->info('Created '.count(self::ROLES).' roles');

        // 2. Super-admin пользователь.
        $admin = User::firstOrCreate(
            ['email' => self::SUPER_ADMIN_EMAIL],
            [
                'name' => self::SUPER_ADMIN_NAME,
                'password' => Hash::make(self::SUPER_ADMIN_PASSWORD),
                'email_verified_at' => now(),
            ]
        );

        if (! $admin->hasRole('super_admin')) {
            $admin->assignRole('super_admin');
        }

        $this->command->info(sprintf(
            'super_admin: %s / %s',
            self::SUPER_ADMIN_EMAIL,
            self::SUPER_ADMIN_PASSWORD,
        ));
    }
}
