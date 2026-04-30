<?php

declare(strict_types=1);

/*
 * Phase 0.8: Filament-панель + 5 ролей (CLAUDE.md §8.1).
 *
 * Проверяем:
 *  - анонимный юзер на /admin/login получает 200 (страница логина)
 *  - анонимный юзер на /admin/* перенаправляется на login
 *  - юзер БЕЗ ролей не может зайти в панель (canAccessPanel = false → 403)
 *  - юзер С ролью super_admin успешно открывает /admin
 *  - юзер с ролью viewer тоже может зайти (read-only по дизайну)
 */

use App\Models\User;
use Database\Seeders\RolesAndAdminSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    // Заводим 5 ролей перед каждым тестом.
    $this->seed(RolesAndAdminSeeder::class);
});

it('login page is publicly accessible', function (): void {
    $this->get('/admin/login')
        ->assertOk();
});

it('redirects guests from dashboard to login', function (): void {
    $this->get('/admin')
        ->assertRedirect('/admin/login');
});

it('forbids users without any role', function (): void {
    $user = User::factory()->create();

    $this->actingAs($user)
        ->get('/admin')
        ->assertForbidden();
});

it('allows super_admin into the dashboard', function (): void {
    $admin = User::query()
        ->where('email', 'admin@storybox.tj')
        ->firstOrFail();

    expect($admin->hasRole('super_admin'))->toBeTrue();

    $this->actingAs($admin)
        ->get('/admin')
        ->assertOk();
});

it('allows viewer role read-only access to panel', function (): void {
    $user = User::factory()->create();
    $user->assignRole('viewer');

    $this->actingAs($user)
        ->get('/admin')
        ->assertOk();
});

it('allows super_admin to view the users list', function (): void {
    $admin = User::query()
        ->where('email', 'admin@storybox.tj')
        ->firstOrFail();

    $this->actingAs($admin)
        ->get('/admin/users')
        ->assertOk();
});
