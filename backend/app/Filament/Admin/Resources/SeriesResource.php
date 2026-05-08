<?php

declare(strict_types=1);

namespace App\Filament\Admin\Resources;

use App\Enums\SeriesStatus;
use App\Filament\Admin\Resources\SeriesResource\Pages;
use App\Models\Genre;
use App\Models\Series;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

/**
 * Filament admin для сериалов. Phase 2.6.
 *
 * Translatable поля title/synopsis редактируются как локализованные секции
 * (по одному инпуту на локаль). Phase 8 (Localization) — заменим на
 * Filament-плагин с tab-UX.
 */
final class SeriesResource extends Resource
{
    protected static ?string $model = Series::class;

    protected static ?string $navigationIcon = 'heroicon-o-film';

    protected static ?string $navigationGroup = 'Content';

    protected static ?int $navigationSort = 10;

    protected static ?string $recordTitleAttribute = 'title.ru';

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\Section::make('Title (translations)')
                ->description('Заполните хотя бы ru. Остальные локали могут добавляться постепенно.')
                ->schema([
                    Forms\Components\TextInput::make('title.ru')->label('Русский')->required()->maxLength(255),
                    Forms\Components\TextInput::make('title.en')->label('English')->maxLength(255),
                    Forms\Components\TextInput::make('title.tg')->label('Тоҷикӣ')->maxLength(255),
                    Forms\Components\TextInput::make('title.uz')->label('Oʻzbekcha')->maxLength(255),
                    Forms\Components\TextInput::make('title.kk')->label('Қазақша')->maxLength(255),
                    Forms\Components\TextInput::make('title.ky')->label('Кыргызча')->maxLength(255),
                ])->columns(2),

            Forms\Components\Section::make('Synopsis (translations)')
                ->collapsed()
                ->schema([
                    Forms\Components\Textarea::make('synopsis.ru')->label('Русский')->rows(3),
                    Forms\Components\Textarea::make('synopsis.en')->label('English')->rows(3),
                    Forms\Components\Textarea::make('synopsis.tg')->label('Тоҷикӣ')->rows(3),
                    Forms\Components\Textarea::make('synopsis.uz')->label('Oʻzbekcha')->rows(3),
                    Forms\Components\Textarea::make('synopsis.kk')->label('Қазақша')->rows(3),
                    Forms\Components\Textarea::make('synopsis.ky')->label('Кыргызча')->rows(3),
                ])->columns(2),

            Forms\Components\Section::make('Media')
                ->schema([
                    Forms\Components\TextInput::make('poster_url')
                        ->label('Poster URL')
                        ->url()
                        ->maxLength(2048)
                        ->helperText('Вертикальный 9:16 постер. Phase 4 — загрузка на S3 через FileUpload.'),
                    Forms\Components\TextInput::make('banner_url')
                        ->label('Banner URL')
                        ->url()
                        ->maxLength(2048)
                        ->helperText('Горизонтальный баннер для главной (опционально).'),
                ])->columns(2),

            Forms\Components\Section::make('Monetization & visibility')
                ->schema([
                    Forms\Components\Select::make('status')
                        ->options(collect(SeriesStatus::cases())
                            ->mapWithKeys(fn (SeriesStatus $s): array => [$s->value => ucfirst($s->value)])
                            ->all())
                        ->required()
                        ->default(SeriesStatus::Draft->value)
                        ->helperText('Только Published попадают в /api/v1/home и /series/{id}.'),
                    Forms\Components\DateTimePicker::make('published_at')
                        ->label('Published at')
                        ->seconds(false)
                        ->helperText('Используется для секции new_releases (последние 30 дней).'),
                    Forms\Components\TextInput::make('free_episodes_count')
                        ->numeric()
                        ->minValue(0)
                        ->default(3)
                        ->required()
                        ->helperText('Сколько первых эпизодов доступны бесплатно.'),
                    Forms\Components\Toggle::make('is_premium')
                        ->default(false)
                        ->helperText('Видно только подписчикам (Phase 7).'),
                    Forms\Components\TextInput::make('position')
                        ->numeric()
                        ->default(0)
                        ->required()
                        ->helperText('Меньше = выше в trending. Сортировка ASC.'),
                ])->columns(2),

            Forms\Components\Section::make('Genres')
                ->schema([
                    Forms\Components\Select::make('genres')
                        ->relationship('genres', 'slug')
                        ->multiple()
                        ->preload()
                        ->getOptionLabelFromRecordUsing(fn (Genre $genre): string => $genre->slug.' — '.(string) ($genre->getTranslation('name', 'ru', useFallbackLocale: true) ?? ''))
                        ->helperText('M:N через series_genres pivot.'),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')->sortable(),
                Tables\Columns\ImageColumn::make('poster_url')->label('Poster')->square(),
                Tables\Columns\TextColumn::make('title.ru')->label('Title (RU)')->searchable()->limit(40),
                Tables\Columns\TextColumn::make('status')
                    ->badge()
                    ->color(fn (SeriesStatus $state): string => match ($state) {
                        SeriesStatus::Published => 'success',
                        SeriesStatus::Draft => 'gray',
                        SeriesStatus::Archived => 'danger',
                    }),
                Tables\Columns\TextColumn::make('episodes_count')
                    ->counts('episodes')
                    ->label('Episodes')
                    ->sortable(),
                Tables\Columns\TextColumn::make('free_episodes_count')->label('Free')->sortable(),
                Tables\Columns\IconColumn::make('is_premium')->boolean()->label('Premium'),
                Tables\Columns\TextColumn::make('position')->sortable(),
                Tables\Columns\TextColumn::make('published_at')->dateTime()->sortable(),
            ])
            ->defaultSort('position')
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->options(collect(SeriesStatus::cases())
                        ->mapWithKeys(fn (SeriesStatus $s): array => [$s->value => ucfirst($s->value)])
                        ->all()),
                Tables\Filters\TernaryFilter::make('is_premium'),
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
            'index' => Pages\ListSeries::route('/'),
            'create' => Pages\CreateSeries::route('/create'),
            'edit' => Pages\EditSeries::route('/{record}/edit'),
        ];
    }
}
