<?php

declare(strict_types=1);

namespace App\Filament\Admin\Resources\EpisodeResource\Pages;

use App\Filament\Admin\Resources\EpisodeResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

final class EditEpisode extends EditRecord
{
    protected static string $resource = EpisodeResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}
