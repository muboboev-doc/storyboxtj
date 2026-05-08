<?php

declare(strict_types=1);

/*
 * Phase 2.6: Filament admin для контента (Series / Episode / Genre).
 *
 * Проверяем:
 *  - super_admin может открывать index/create/edit страницы для каждого ресурса
 *  - content_manager (по факту такой же доступ — Phase 2 не разделяет policies)
 *  - анонимный юзер редиректится на /admin/login
 *  - юзер без ролей получает 403 на любом ресурсе
 *
 * Полный CRUD через Livewire-формы — отдельная тема (живёт в Phase 8 +
 * filament-translatable плагин). Здесь — только маршрутизация и доступ.
 */

use App\Models\Episode;
use App\Models\Genre;
use App\Models\Series;
use App\Models\User;
use Database\Seeders\RolesAndAdminSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    $this->seed(RolesAndAdminSeeder::class);

    $this->admin = User::query()
        ->where('email', 'admin@storybox.tj')
        ->firstOrFail();
});

describe('Genres resource', function (): void {
    it('lists genres for super_admin', function (): void {
        Genre::factory()->drama()->create();

        $this->actingAs($this->admin)
            ->get('/admin/genres')
            ->assertOk();
    });

    it('opens create page for super_admin', function (): void {
        $this->actingAs($this->admin)
            ->get('/admin/genres/create')
            ->assertOk();
    });

    it('opens edit page for existing genre', function (): void {
        $genre = Genre::factory()->drama()->create();

        $this->actingAs($this->admin)
            ->get("/admin/genres/{$genre->id}/edit")
            ->assertOk();
    });

    it('redirects guest to login', function (): void {
        $this->get('/admin/genres')->assertRedirect('/admin/login');
    });

    it('forbids users without role', function (): void {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->get('/admin/genres')
            ->assertForbidden();
    });
});

describe('Series resource', function (): void {
    it('lists series for super_admin', function (): void {
        Series::factory()->published()->create();

        $this->actingAs($this->admin)
            ->get('/admin/series')
            ->assertOk();
    });

    it('opens create page for super_admin', function (): void {
        $this->actingAs($this->admin)
            ->get('/admin/series/create')
            ->assertOk();
    });

    it('opens edit page for existing series', function (): void {
        $series = Series::factory()->published()->create();

        $this->actingAs($this->admin)
            ->get("/admin/series/{$series->id}/edit")
            ->assertOk();
    });

    it('content_manager has access to series', function (): void {
        $manager = User::factory()->create();
        $manager->assignRole('content_manager');

        $this->actingAs($manager)
            ->get('/admin/series')
            ->assertOk();
    });

    it('redirects guest to login', function (): void {
        $this->get('/admin/series')->assertRedirect('/admin/login');
    });
});

describe('Episodes resource', function (): void {
    it('lists episodes for super_admin', function (): void {
        $series = Series::factory()->published()->create();
        Episode::factory()->ready()->forSeries($series, 1)->create();

        $this->actingAs($this->admin)
            ->get('/admin/episodes')
            ->assertOk();
    });

    it('opens create page for super_admin', function (): void {
        $this->actingAs($this->admin)
            ->get('/admin/episodes/create')
            ->assertOk();
    });

    it('opens edit page for existing episode', function (): void {
        $series = Series::factory()->published()->create();
        $episode = Episode::factory()->ready()->forSeries($series, 1)->create();

        $this->actingAs($this->admin)
            ->get("/admin/episodes/{$episode->id}/edit")
            ->assertOk();
    });

    it('redirects guest to login', function (): void {
        $this->get('/admin/episodes')->assertRedirect('/admin/login');
    });

    it('forbids users without role', function (): void {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->get('/admin/episodes')
            ->assertForbidden();
    });
});

describe('Resources are registered in the panel', function (): void {
    it('Filament discovers GenreResource', function (): void {
        expect(class_exists(\App\Filament\Admin\Resources\GenreResource::class))->toBeTrue();
    });

    it('Filament discovers SeriesResource', function (): void {
        expect(class_exists(\App\Filament\Admin\Resources\SeriesResource::class))->toBeTrue();
    });

    it('Filament discovers EpisodeResource', function (): void {
        expect(class_exists(\App\Filament\Admin\Resources\EpisodeResource::class))->toBeTrue();
    });
});
