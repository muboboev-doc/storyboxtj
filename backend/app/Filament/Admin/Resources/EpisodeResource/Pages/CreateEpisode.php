<?php

declare(strict_types=1);

namespace App\Filament\Admin\Resources\EpisodeResource\Pages;

use App\Filament\Admin\Resources\EpisodeResource;
use Filament\Resources\Pages\CreateRecord;

final class CreateEpisode extends CreateRecord
{
    protected static string $resource = EpisodeResource::class;
}
