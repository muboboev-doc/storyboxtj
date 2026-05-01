<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
 * Phase 2.1: жанры контента (драма, романтика, детектив, и т.д.).
 *
 * docs/tz.md §5.9. CLAUDE.md §11 — name JSON-translatable на 6 языков
 * через Spatie Translatable.
 *
 * Связь с series — через pivot `series_genres` (M:N).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('genres', function (Blueprint $table): void {
            $table->id();

            // Translatable JSON: {"ru":"Драма","en":"Drama","tg":"...","uz":"...","kk":"...","ky":"..."}.
            $table->json('name');

            // Slug для URL (`/discover?genre=drama`). Уникален и на латинице.
            $table->string('slug', 64)->unique();

            // Сортировка в /discover. Меньше = выше.
            $table->unsignedSmallInteger('position')->default(0);

            // Скрыть из /discover не удаляя (для архива).
            $table->boolean('is_active')->default(true);

            $table->timestamps();

            $table->index(['is_active', 'position']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('genres');
    }
};
