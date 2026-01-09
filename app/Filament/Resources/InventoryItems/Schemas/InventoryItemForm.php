<?php

namespace App\Filament\Resources\InventoryItems\Schemas;

use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Components\Repeater;
use Filament\Schemas\Schema;

class InventoryItemForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('name')->required(),
                Select::make('purchase_unit_id')->relationship('purchaseUnit', 'name')->required(),
                Select::make('recipe_unit_id')->relationship('recipeUnit', 'name')->required(),
                TextInput::make('qty_per_purchase_unit')->numeric()->required(),
                TextInput::make('minimum_limit')->numeric(),
                Textarea::make('notes'),
                Select::make('company_id')->relationship('company', 'name')->required(),
                Select::make('location_id')->relationship('location', 'name'),
                Toggle::make('status'),
            ]);
    }
}
