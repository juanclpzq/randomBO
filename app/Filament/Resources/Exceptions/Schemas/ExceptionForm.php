<?php

namespace App\Filament\Resources\Exceptions\Schemas;

use Filament\Schemas\Schema;

class ExceptionForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                \Filament\Forms\Components\TextInput::make('name')->required(),
                \Filament\Forms\Components\Select::make('company_id')
                    ->label('Empresa')
                    ->searchable()
                    ->options(fn () => \App\Models\Company::where('status', true)->whereNull('deleted_at')->pluck('name', 'id')),
                \Filament\Forms\Components\Select::make('location_id')
                    ->label('Sucursal')
                    ->searchable()
                    ->options(fn () => \App\Models\Location::where('status', true)->whereNull('deleted_at')->pluck('name', 'id')),
                \Filament\Forms\Components\Toggle::make('status')
                    ->label('Activo')
                    ->default(true),
            ]);
    }
}
