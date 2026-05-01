<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
 * Phase 2.1: сериалы (вертикальные драмы).
 *
 * docs/tz.md §5.10. Все user-facing strings — JSON-translatable
 * через Spatie Translatable (CLAUDE.md §11).
 *
 * Связи:
 *  - belongsToMany Genre via series_genres
 *  - hasMany Episode (1 series → много episodes)
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('series', function (Blueprint $table): void {
            $table->id();

            // Translatable.
            $table->json('title');
            $table->json('synopsis')->nullable();

            // Постер (вертикальный 9:16) и баннер (горизонтальный 16:9).
            $table->string('poster_url', 500)->nullable();
            $table->string('banner_url', 500)->nullable();

            // Бесплатные эпизоды — первые N штук бесплатно (CLAUDE.md §1).
            $table->unsignedSmallInteger('free_episodes_count')->default(3);

            // Денормализованный счётчик (обновляется через Observer).
            // Оптимизация для /home / discover-листингов.
            $table->unsignedInteger('total_episodes')->default(0);

            // Жизненный цикл (App\Enums\SeriesStatus).
            $table->enum('status', ['draft', 'published', 'archived'])
                ->default('draft');

            // Премиум сериалы — только VIP подписка (Phase 5+).
            $table->boolean('is_premium')->default(false);

            // Сортировка в /home «Тренды» и т.п.
            $table->unsignedInteger('position')->default(0);

            // Когда стал виден в каталоге.
            $table->timestamp('published_at')->nullable();

            $table->timestamps();

            // Индексы для популярных запросов (CLAUDE.md §5.2).
            $table->index(['status', 'published_at']);
            $table->index('position');
            // FULLTEXT JSON не поддерживает; добавим в Phase 7 search через MeiliSearch.
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('series');
    }
};
