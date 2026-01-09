<?php

namespace App\Filament\Resources\Companies\Schemas;

use Filament\Schemas\Schema;

class CompanyForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                \Filament\Forms\Components\TextInput::make('name')->label('Nombre')->required(),
                \Filament\Forms\Components\TextInput::make('legal_name')->label('Razón social'),
                \Filament\Forms\Components\TextInput::make('tax_id')->label('RFC'),
                \Filament\Forms\Components\TextInput::make('email')->label('Email'),
                \Filament\Forms\Components\TextInput::make('phone')->label('Teléfono'),
                \Filament\Forms\Components\TextInput::make('address')->label('Dirección'),
                \Filament\Forms\Components\TextInput::make('language')->label('Idioma'),
                \Filament\Forms\Components\TextInput::make('membership_plan_id')->label('Plan de membresía')->numeric(),
                \Filament\Forms\Components\DatePicker::make('subscription_start')->label('Inicio suscripción'),
                \Filament\Forms\Components\DatePicker::make('subscription_end')->label('Fin suscripción'),
                \Filament\Forms\Components\Toggle::make('subscription_status')
                    ->label('Suscripción Activa')
                    ->onColor('success')
                    ->offColor('danger')
                    ->inline()
                    ->default(true)
                        ->afterStateHydrated(function ($component, $state) {
                            // Si el valor es null (nuevo registro), mostrar activo
                            if (is_null($state)) {
                                $component->state(true);
                            } else {
                                $component->state((int)$state === 1 || $state === true);
                            }
                        })
                        ->dehydrateStateUsing(fn ($state) => $state ? 1 : 0),
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
