<?php

namespace App\Filament\Resources\Employees\Schemas;

use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Textarea;
use Filament\Schemas\Schema;

class EmployeeForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('first_name')
                    ->required(),
                TextInput::make('last_name')
                    ->required(),
                TextInput::make('email')
                    ->label('Email address')
                    ->email()
                    ->required(),
                TextInput::make('phone')
                    ->tel(),
                TextInput::make('password_hash')
                    ->required(),
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
                Select::make('company_id')
                    ->relationship('company', 'name')
                    ->required(),
                Select::make('location_id')
                    ->relationship('location', 'name'),
            ]);
    }
}
