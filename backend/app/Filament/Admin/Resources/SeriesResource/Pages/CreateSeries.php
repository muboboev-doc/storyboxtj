<?php

declare(strict_types=1);

namespace App\Filament\Admin\Resources\SeriesResource\Pages;

use App\Filament\Admin\Resources\SeriesResource;
use Filament\Resources\Pages\CreateRecord;

final class CreateSeries extends CreateRecord
{
    protected static string $resource = SeriesResource::class;
}
