<?php

namespace App\Filament\Resources\Items\Schemas;

use Filament\Schemas\Schema;

class ItemForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                \Filament\Forms\Components\TextInput::make('name')->label('Nombre')->required(),
                \Filament\Forms\Components\TextInput::make('description')->label('Descripción'),
                \Filament\Forms\Components\TextInput::make('sku')->label('SKU'),
                \Filament\Forms\Components\TextInput::make('price')->label('Precio')->numeric()->required(),
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
                \Filament\Forms\Components\Select::make('category_id')
                    ->label('Categoría')
                    ->options(fn () => \App\Models\Category::where('status', 1)->whereNull('deleted_at')->pluck('name', 'id'))
                    ->searchable()
                    ->required(),
                \Filament\Forms\Components\Select::make('company_id')
                    ->label('Compañía')
                    ->options(fn () => \App\Models\Company::where('status', 1)->whereNull('deleted_at')->pluck('name', 'id'))
                    ->searchable()
                    ->required(),
                \Filament\Forms\Components\MultiSelect::make('modifierGroups')
                    ->label('Grupos de modificadores')
                    ->options(fn () => \App\Models\ModifierGroup::where('status', 1)->whereNull('deleted_at')->pluck('name', 'id'))
                    ->searchable(),
                \Filament\Forms\Components\MultiSelect::make('modifiers')
                    ->label('Modificadores')
                    ->options(fn () => \App\Models\Modifier::where('status', 1)->whereNull('deleted_at')->pluck('name', 'id'))
                    ->searchable(),
                \Filament\Forms\Components\MultiSelect::make('exceptions')
                    ->label('Excepciones')
                    ->options(fn () => \App\Models\Exception::where('status', 1)->whereNull('deleted_at')->pluck('name', 'id'))
                    ->searchable(),
                \Filament\Forms\Components\MultiSelect::make('extras')
                    ->label('Extras')
                    ->options(fn () => \App\Models\Extra::where('status', 1)->whereNull('deleted_at')->pluck('name', 'id'))
                    ->searchable(),
            ]);
    }
}
