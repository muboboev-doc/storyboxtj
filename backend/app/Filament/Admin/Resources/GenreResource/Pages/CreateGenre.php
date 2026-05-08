<?php

declare(strict_types=1);

namespace App\Filament\Admin\Resources\GenreResource\Pages;

use App\Filament\Admin\Resources\GenreResource;
use Filament\Resources\Pages\CreateRecord;

final class CreateGenre extends CreateRecord
{
    protected static string $resource = GenreResource::class;
}
