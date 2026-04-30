<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * Тестовые пользователи всех 4 непривилегированных ролей + 1 без роли.
 *
 * Используется на dev/staging для smoke-тестирования авторизации в /admin
 * и (после Phase 1) для тестирования API.
 *
 * НЕ запускается на production (проверка APP_ENV в DatabaseSeeder).
 *
 * Пароль для всех — `password` (открыт для удобства разработки).
 */
final class TestUsersSeeder extends Seeder
{
    /** @var list<array{email:string,name:string,role:?string}> */
    private const USERS = [
        ['email' => 'content@storybox.tj', 'name' => 'Content Manager (test)', 'role' => 'content_manager'],
        ['email' => 'finance@storybox.tj', 'name' => 'Finance Manager (test)', 'role' => 'finance_manager'],
        ['email' => 'support@storybox.tj', 'name' => 'Support (test)', 'role' => 'support'],
        ['email' => 'viewer@storybox.tj', 'name' => 'Viewer (test)', 'role' => 'viewer'],
        // User without role — для проверки что 403 на /admin работает.
        ['email' => 'noroles@storybox.tj', 'name' => 'No-Roles (test)', 'role' => null],
    ];

    public function run(): void
    {
        $created = 0;

        foreach (self::USERS as $data) {
            $user = User::firstOrCreate(
                ['email' => $data['email']],
                [
                    'name' => $data['name'],
                    'password' => Hash::make('password'),
                    'email_verified_at' => now(),
                ]
            );

            if ($data['role'] !== null && ! $user->hasRole($data['role'])) {
                $user->assignRole($data['role']);
            }

            $created++;
        }

        $this->command->info("Created/updated {$created} test users (password: 'password')");
        $this->command->table(
            ['Email', 'Role'],
            array_map(
                static fn (array $u): array => [$u['email'], $u['role'] ?? '— (no role)'],
                self::USERS,
            ),
        );
    }
}
