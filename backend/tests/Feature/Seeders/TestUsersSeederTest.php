<?php

declare(strict_types=1);

/*
 * Phase 0.9: TestUsersSeeder создаёт 5 тестовых юзеров
 * (4 с ролями + 1 без роли) для smoke-тестирования /admin.
 *
 * Сидер должен быть идемпотентен (firstOrCreate) — повторный запуск
 * не создаёт дублей.
 */

use App\Models\User;
use Database\Seeders\RolesAndAdminSeeder;
use Database\Seeders\TestUsersSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    // Роли нужны до TestUsersSeeder, иначе assignRole() упадёт.
    $this->seed(RolesAndAdminSeeder::class);
});

it('creates 5 test users with expected roles', function (): void {
    $this->seed(TestUsersSeeder::class);

    $expected = [
        'content@storybox.tj' => 'content_manager',
        'finance@storybox.tj' => 'finance_manager',
        'support@storybox.tj' => 'support',
        'viewer@storybox.tj' => 'viewer',
        'noroles@storybox.tj' => null,
    ];

    foreach ($expected as $email => $role) {
        $user = User::where('email', $email)->first();
        expect($user)->not->toBeNull("User {$email} should exist");

        if ($role === null) {
            expect($user->roles)->toBeEmpty("User {$email} should have no roles");
        } else {
            expect($user->hasRole($role))->toBeTrue("User {$email} should have role {$role}");
        }
    }
});

it('is idempotent on re-run', function (): void {
    $this->seed(TestUsersSeeder::class);
    $countAfterFirst = User::count();

    $this->seed(TestUsersSeeder::class);
    $countAfterSecond = User::count();

    expect($countAfterSecond)->toBe($countAfterFirst);
});

it('all test users can log in with password "password"', function (): void {
    $this->seed(TestUsersSeeder::class);

    $emails = [
        'content@storybox.tj',
        'finance@storybox.tj',
        'support@storybox.tj',
        'viewer@storybox.tj',
        'noroles@storybox.tj',
    ];

    foreach ($emails as $email) {
        $user = User::where('email', $email)->firstOrFail();
        expect(Hash::check('password', $user->password))
            ->toBeTrue("User {$email} should authenticate with 'password'");
    }
});
