<?php

namespace App\Filament\Resources\Units\Schemas;

use Filament\Forms\Components\TextInput;
use Filament\Schemas\Schema;

class UnitForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('name')
                    ->required(),
                TextInput::make('short_name'),
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
            ]);
    }
}
