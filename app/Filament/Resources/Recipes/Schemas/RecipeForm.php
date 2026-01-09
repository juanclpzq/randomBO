<?php

namespace App\Filament\Resources\Recipes\Schemas;

use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Schema;

use App\Models\InventoryItem;
use App\Models\Unit;

class RecipeForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('name')
                    ->required(),
                Textarea::make('description')
                    ->columnSpanFull(),
                Toggle::make('is_base'),
                \Filament\Forms\Components\Repeater::make('RecipeIngredients')
                    ->label('Ingredientes')
                    ->schema([
                        \Filament\Forms\Components\Select::make('inventory_item_id')
                            ->label('Ingrediente')
                            ->options(InventoryItem::query()->pluck('name', 'id'))
                            ->searchable()
                            ->required(),
                        \Filament\Forms\Components\TextInput::make('quantity')
                            ->label('Cantidad')
                            ->numeric()
                            ->required(),
                        \Filament\Forms\Components\Select::make('unit_id')
                            ->label('Unidad')
                            ->options(Unit::query()->pluck('name', 'id'))
                            ->searchable()
                            ->required(),
                    ])
                    ->createItemButtonLabel('Agregar ingrediente')
                    ->columns(3)
                    ->columnSpanFull()
                    ->relationship()
                    ->reorderable()
                    ->cloneable()
                    ->collapsible(),
            ]);
    }
}