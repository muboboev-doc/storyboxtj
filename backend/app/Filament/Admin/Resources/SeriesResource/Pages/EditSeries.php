<?php

declare(strict_types=1);

namespace App\Filament\Admin\Resources\SeriesResource\Pages;

use App\Filament\Admin\Resources\SeriesResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

final class EditSeries extends EditRecord
{
    protected static string $resource = SeriesResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}
