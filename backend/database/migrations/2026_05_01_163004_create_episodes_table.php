<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
 * Phase 2.1: эпизоды (60-120 секунд видео).
 *
 * docs/tz.md §5.12.
 *
 * Связи:
 *  - belongsTo Series
 *  - hasMany EpisodeStream (one episode → multiple HLS qualities)
 *  - (Phase 8) hasMany EpisodeKey (DRM keys)
 *  - (Phase 3) hasMany UserEpisodeUnlock
 *
 * Жизненный цикл status: uploaded → transcoding → ready (или failed)
 * App\Enums\EpisodeStatus.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('episodes', function (Blueprint $table): void {
            $table->id();

            $table->foreignId('series_id')
                ->constrained('series')
                ->cascadeOnDelete();

            // Номер эпизода в сериале (1, 2, 3, ...). Сезоны — out of scope MVP.
            $table->unsignedSmallInteger('number');

            // Translatable. Title опционален (часто эпизоды без отдельных названий).
            $table->json('title')->nullable();
            $table->json('synopsis')->nullable();

            // Длительность в секундах (60-120 типично).
            $table->unsignedSmallInteger('duration_sec')->default(0);

            // Бесплатный эпизод? Дефолт false; Series.free_episodes_count первых
            // эпизодов получают is_free=true через Observer/Service.
            $table->boolean('is_free')->default(false);

            // Стоимость разблокировки в коинах (если is_free=false).
            // Phase 3 EpisodeUnlockService использует.
            $table->unsignedSmallInteger('unlock_cost_coins')->default(30);

            // Стадия процесса (uploaded → transcoding → ready / failed).
            $table->enum('status', ['uploaded', 'transcoding', 'ready', 'failed'])
                ->default('uploaded');

            // URL оригинального файла во временном S3 (до transcode).
            // После Phase 4 transcode — поле очищается, оригинал может быть
            // удалён (cost saving).
            $table->string('original_url', 500)->nullable();

            $table->timestamp('published_at')->nullable();

            $table->timestamps();

            // Уникальность: один эпизод с одним номером в сериале.
            $table->unique(['series_id', 'number']);

            // Быстрый листинг эпизодов сериала.
            $table->index(['series_id', 'number']);
            $table->index(['status', 'published_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('episodes');
    }
};
