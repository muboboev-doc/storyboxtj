<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
 * Phase 2.1: pivot table series ↔ genres (M:N).
 *
 * docs/tz.md §5.11. Один сериал может иметь несколько жанров
 * (например, "драма" + "романтика" + "комедия").
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('series_genres', function (Blueprint $table): void {
            $table->foreignId('series_id')
                ->constrained('series')
                ->cascadeOnDelete();
            $table->foreignId('genre_id')
                ->constrained('genres')
                ->cascadeOnDelete();

            $table->primary(['series_id', 'genre_id']);

            $table->index('genre_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('series_genres');
    }
};
