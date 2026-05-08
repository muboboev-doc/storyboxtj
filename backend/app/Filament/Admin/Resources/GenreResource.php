<?php

declare(strict_types=1);

namespace App\Filament\Admin\Resources;

use App\Filament\Admin\Resources\GenreResource\Pages;
use App\Models\Genre;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

/**
 * Filament admin для жанров. Phase 2.6.
 *
 * Translatable `name` редактируется через JSON-поля для каждой локали
 * (упрощённый вариант). В Phase 8 (Localization) добавим Filament-плагин
 * для locale-tab UX.
 */
final class GenreResource extends Resource
{
    protected static ?string $model = Genre::class;

    protected static ?string $navigationIcon = 'heroicon-o-tag';

    protected static ?string $navigationGroup = 'Content';

    protected static ?int $navigationSort = 30;

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\TextInput::make('slug')
                ->required()
                ->maxLength(64)
                ->alphaDash()
                ->unique(ignoreRecord: true),

            Forms\Components\Section::make('Name (translations)')
                ->description('Заполните хотя бы ru. Остальные локали могут добавляться постепенно.')
                ->schema([
                    Forms\Components\TextInput::make('name.ru')->label('Русский')->required(),
                    Forms\Components\TextInput::make('name.en')->label('English'),
                    Forms\Components\TextInput::make('name.tg')->label('Тоҷикӣ'),
                    Forms\Components\TextInput::make('name.uz')->label('Oʻzbekcha'),
                    Forms\Components\TextInput::make('name.kk')->label('Қазақша'),
                    Forms\Components\TextInput::make('name.ky')->label('Кыргызча'),
                ])->columns(2),

            Forms\Components\TextInput::make('position')
                ->numeric()
                ->default(0)
                ->helperText('Меньше = выше в /discover'),

            Forms\Components\Toggle::make('is_active')
                ->default(true)
                ->helperText('Скрывает жанр без удаления (можно вернуть позже)'),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')->sortable(),
                Tables\Columns\TextColumn::make('slug')->searchable()->sortable(),
                Tables\Columns\TextColumn::make('name.ru')->label('Name (RU)'),
                Tables\Columns\TextColumn::make('position')->sortable(),
                Tables\Columns\IconColumn::make('is_active')->boolean(),
                Tables\Columns\TextColumn::make('series_count')
                    ->counts('series')
                    ->label('Series')
                    ->sortable(),
            ])
            ->defaultSort('position')
            ->filters([
                Tables\Filters\TernaryFilter::make('is_active'),
            ])
            ->actions([
                Tables\Actions\EditAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListGenres::route('/'),
            'create' => Pages\CreateGenre::route('/create'),
            'edit' => Pages\EditGenre::route('/{record}/edit'),
        ];
    }
}
