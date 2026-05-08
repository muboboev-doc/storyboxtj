<?php

declare(strict_types=1);

namespace App\Filament\Admin\Resources\EpisodeResource\Pages;

use App\Filament\Admin\Resources\EpisodeResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

final class ListEpisodes extends ListRecords
{
    protected static string $resource = EpisodeResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}
