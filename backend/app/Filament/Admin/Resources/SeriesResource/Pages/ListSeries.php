<?php

declare(strict_types=1);

namespace App\Filament\Admin\Resources\SeriesResource\Pages;

use App\Filament\Admin\Resources\SeriesResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

final class ListSeries extends ListRecords
{
    protected static string $resource = SeriesResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}
