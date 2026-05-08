<?php

declare(strict_types=1);

namespace App\Filament\Admin\Resources;

use App\Enums\EpisodeStatus;
use App\Filament\Admin\Resources\EpisodeResource\Pages;
use App\Models\Episode;
use App\Models\Series;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

/**
 * Filament admin для эпизодов. Phase 2.6.
 *
 * Phase 2.7 добавит FileUpload для оригинального видео + диспатч TranscodeEpisode
 * job. Phase 4 — episode_streams (manifest_url, segment_base_url) появятся как
 * RelationManager.
 */
final class EpisodeResource extends Resource
{
    protected static ?string $model = Episode::class;

    protected static ?string $navigationIcon = 'heroicon-o-play-circle';

    protected static ?string $navigationGroup = 'Content';

    protected static ?int $navigationSort = 20;

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\Section::make('Series & numbering')
                ->schema([
                    Forms\Components\Select::make('series_id')
                        ->relationship('series', 'id')
                        ->searchable()
                        ->preload()
                        ->required()
                        ->getOptionLabelFromRecordUsing(fn (Series $series): string => '#'.$series->id.' — '.(string) ($series->getTranslation('title', 'ru', useFallbackLocale: true) ?? '(no title)')),
                    Forms\Components\TextInput::make('number')
                        ->numeric()
                        ->minValue(1)
                        ->required()
                        ->helperText('Номер эпизода в сериале (1-based). Уникален в рамках series_id.'),
                ])->columns(2),

            Forms\Components\Section::make('Title (translations)')
                ->collapsed()
                ->schema([
                    Forms\Components\TextInput::make('title.ru')->label('Русский')->maxLength(255),
                    Forms\Components\TextInput::make('title.en')->label('English')->maxLength(255),
                    Forms\Components\TextInput::make('title.tg')->label('Тоҷикӣ')->maxLength(255),
                    Forms\Components\TextInput::make('title.uz')->label('Oʻzbekcha')->maxLength(255),
                    Forms\Components\TextInput::make('title.kk')->label('Қазақша')->maxLength(255),
                    Forms\Components\TextInput::make('title.ky')->label('Кыргызча')->maxLength(255),
                ])->columns(2),

            Forms\Components\Section::make('Synopsis (translations)')
                ->collapsed()
                ->schema([
                    Forms\Components\Textarea::make('synopsis.ru')->label('Русский')->rows(2),
                    Forms\Components\Textarea::make('synopsis.en')->label('English')->rows(2),
                    Forms\Components\Textarea::make('synopsis.tg')->label('Тоҷикӣ')->rows(2),
                    Forms\Components\Textarea::make('synopsis.uz')->label('Oʻzbekcha')->rows(2),
                    Forms\Components\Textarea::make('synopsis.kk')->label('Қазақша')->rows(2),
                    Forms\Components\Textarea::make('synopsis.ky')->label('Кыргызча')->rows(2),
                ])->columns(2),

            Forms\Components\Section::make('Playback & monetization')
                ->schema([
                    Forms\Components\TextInput::make('duration_sec')
                        ->numeric()
                        ->minValue(0)
                        ->required()
                        ->default(0)
                        ->suffix('sec')
                        ->helperText('Длительность в секундах. Phase 2.7 — заполняется автоматически по результатам ffprobe.'),
                    Forms\Components\Toggle::make('is_free')
                        ->default(false)
                        ->helperText('Если включён — эпизод доступен без разблокировки. Иначе срабатывает unlock_cost_coins.'),
                    Forms\Components\TextInput::make('unlock_cost_coins')
                        ->numeric()
                        ->minValue(0)
                        ->default(30)
                        ->required()
                        ->suffix('coins')
                        ->helperText('Стоимость разблокировки. Используется при HTTP 403 EPISODE_LOCKED.'),
                ])->columns(3),

            Forms\Components\Section::make('Source & status')
                ->schema([
                    Forms\Components\Select::make('status')
                        ->options(collect(EpisodeStatus::cases())
                            ->mapWithKeys(fn (EpisodeStatus $s): array => [$s->value => ucfirst($s->value)])
                            ->all())
                        ->default(EpisodeStatus::Uploaded->value)
                        ->required()
                        ->helperText('Только Ready попадает в /api/v1/series/{id} и /api/v1/episodes/{id}.'),
                    Forms\Components\TextInput::make('original_url')
                        ->label('Original video URL')
                        ->url()
                        ->maxLength(2048)
                        ->helperText('Phase 2.7: FileUpload → S3 → ставится автоматически.'),
                    Forms\Components\DateTimePicker::make('published_at')
                        ->seconds(false)
                        ->helperText('Опционально. Используется для расписания.'),
                ])->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')->sortable(),
                Tables\Columns\TextColumn::make('series.id')
                    ->label('Series')
                    ->formatStateUsing(fn (Episode $record): string => '#'.$record->series_id.' — '.(string) ($record->series->getTranslation('title', 'ru', useFallbackLocale: true) ?? ''))
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('number')->label('Ep #')->sortable(),
                Tables\Columns\TextColumn::make('title.ru')->label('Title (RU)')->limit(40),
                Tables\Columns\TextColumn::make('duration_sec')->label('Duration (s)')->sortable(),
                Tables\Columns\IconColumn::make('is_free')->boolean()->label('Free'),
                Tables\Columns\TextColumn::make('unlock_cost_coins')->label('Cost')->sortable(),
                Tables\Columns\TextColumn::make('status')
                    ->badge()
                    ->color(fn (EpisodeStatus $state): string => match ($state) {
                        EpisodeStatus::Ready => 'success',
                        EpisodeStatus::Transcoding => 'warning',
                        EpisodeStatus::Uploaded => 'gray',
                        EpisodeStatus::Failed => 'danger',
                    }),
                Tables\Columns\TextColumn::make('published_at')->dateTime()->sortable(),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->options(collect(EpisodeStatus::cases())
                        ->mapWithKeys(fn (EpisodeStatus $s): array => [$s->value => ucfirst($s->value)])
                        ->all()),
                Tables\Filters\TernaryFilter::make('is_free'),
                Tables\Filters\SelectFilter::make('series_id')
                    ->relationship('series', 'id')
                    ->searchable()
                    ->preload()
                    ->label('Series'),
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
            'index' => Pages\ListEpisodes::route('/'),
            'create' => Pages\CreateEpisode::route('/create'),
            'edit' => Pages\EditEpisode::route('/{record}/edit'),
        ];
    }
}
