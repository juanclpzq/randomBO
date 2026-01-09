<?php

namespace App\Filament\Resources\Locations\Schemas;

use Filament\Schemas\Schema;

class LocationForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                \Filament\Forms\Components\TextInput::make('name')->label('Nombre')->required(),
                \Filament\Forms\Components\TextInput::make('address')->label('Dirección'),
                \Filament\Forms\Components\TextInput::make('phone')->label('Teléfono'),
                \Filament\Forms\Components\TextInput::make('email')->label('Email'),
                \Filament\Forms\Components\Select::make('company_id')
                    ->label('Empresa')
                    ->searchable()
                    ->options(fn () => \App\Models\Company::where('status', true)->whereNull('deleted_at')->pluck('name', 'id')),
                \Filament\Forms\Components\Toggle::make('status')
                    ->label('Activo')
                    ->onColor('success')
                    ->offColor('danger')
                    ->inline()
                    ->default(true)
                    ->afterStateHydrated(function ($component, $state) {
                        if (is_null($state)) {
                            $component->state(true);
                        } else {
                            $component->state((int)$state === 1 || $state === true);
                        }
                    })
                    ->dehydrateStateUsing(fn ($state) => $state ? 1 : 0),
            ]);
    }
}
