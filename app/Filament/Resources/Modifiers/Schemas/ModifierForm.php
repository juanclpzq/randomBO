<?php

namespace App\Filament\Resources\Modifiers\Schemas;

use Filament\Schemas\Schema;

class ModifierForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                \Filament\Forms\Components\TextInput::make('name')->label('Nombre')->required(),
                \Filament\Forms\Components\TextInput::make('description')->label('Descripción'),
                \Filament\Forms\Components\Toggle::make('status')
                    ->label('Activo')
                    ->onColor('success')
                    ->offColor('danger')
                    ->inline()
                    ->default(true)
                    ->afterStateHydrated(function ($component, $state) {
                        $component->state((int)$state === 1 || $state === true);
                    })
                    ->dehydrateStateUsing(fn ($state) => $state ? 1 : 0),
                \Filament\Forms\Components\TextInput::make('price_change')->label('Cambio de precio')->numeric(),
                \Filament\Forms\Components\TextInput::make('sort_order')->label('Orden')->numeric(),
                \Filament\Forms\Components\Select::make('modifier_group_id')
                    ->label('Grupo')
                    ->options(fn () => \App\Models\ModifierGroup::where('status', 1)->whereNull('deleted_at')->pluck('name', 'id'))
                    ->searchable()
                    ->required(),
                \Filament\Forms\Components\Select::make('company_id')
                    ->label('Compañía')
                    ->options(fn () => \App\Models\Company::where('status', 1)->whereNull('deleted_at')->pluck('name', 'id'))
                    ->searchable()
                    ->required(),
            ]);
    }
}
