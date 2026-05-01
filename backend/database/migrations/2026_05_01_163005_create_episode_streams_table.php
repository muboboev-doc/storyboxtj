<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
 * Phase 2.1: HLS-потоки разного качества для эпизода.
 *
 * docs/tz.md §5.13.
 *
 * Один Episode → несколько streams (240p / 480p / 720p / 1080p).
 * Создаются автоматически в Phase 4 после TranscodeEpisode job'а.
 *
 * `manifest_url` — публичный URL m3u8 (через CDN с signed URL).
 * `segment_base_url` — корень для .ts/.m4s сегментов.
 *
 * `drm_protected` различает Phase 4 (только AES-128) и Phase 9 (Widevine/FairPlay).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('episode_streams', function (Blueprint $table): void {
            $table->id();

            $table->foreignId('episode_id')
                ->constrained('episodes')
                ->cascadeOnDelete();

            // App\Enums\StreamQuality.
            $table->enum('quality', ['240p', '480p', '720p', '1080p']);

            // URL master.m3u8 (или per-quality variant.m3u8).
            $table->string('manifest_url', 500);

            // Базовый URL для сегментов (`<base>/segment_001.ts`).
            $table->string('segment_base_url', 500)->nullable();

            // Phase 9: true для Widevine/FairPlay; false для plain AES-128.
            $table->boolean('drm_protected')->default(false);

            // Размер для аналитики storage costs.
            $table->unsignedBigInteger('file_size_bytes')->default(0);

            $table->timestamps();

            $table->unique(['episode_id', 'quality']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('episode_streams');
    }
};
