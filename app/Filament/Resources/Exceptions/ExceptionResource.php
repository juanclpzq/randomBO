<?php

namespace App\Filament\Resources\Exceptions;

use App\Filament\Resources\Exceptions\Pages\CreateException;
use App\Filament\Resources\Exceptions\Pages\EditException;
use App\Filament\Resources\Exceptions\Pages\ListExceptions;
use App\Filament\Resources\Exceptions\Schemas\ExceptionForm;
use App\Filament\Resources\Exceptions\Tables\ExceptionsTable;
use App\Models\Exception;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\SoftDeletingScope;

class ExceptionResource extends Resource
{
    protected static ?string $model = Exception::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedRectangleStack;

    protected static ?string $recordTitleAttribute = 'name';

    public static function form(Schema $schema): Schema
    {
        return ExceptionForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return ExceptionsTable::configure($table);
    }

    public static function getRelations(): array
    {
        return [
            //
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListExceptions::route('/'),
            'create' => CreateException::route('/create'),
            'edit' => EditException::route('/{record}/edit'),
        ];
    }

    public static function getRecordRouteBindingEloquentQuery(): Builder
    {
        return parent::getRecordRouteBindingEloquentQuery()
            ->withoutGlobalScopes([
                SoftDeletingScope::class,
            ]);
    }
}
