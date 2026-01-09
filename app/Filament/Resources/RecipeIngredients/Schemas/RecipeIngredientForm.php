<?php

namespace App\Filament\Resources\RecipeIngredients\Schemas;

use Filament\Forms\Components\TextInput;
use Filament\Schemas\Schema;

class RecipeIngredientForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('recipe_id')
                    ->required(),
                TextInput::make('inventory_item_id')
                    ->required(),
                TextInput::make('quantity')
                    ->required()
                    ->numeric(),
                TextInput::make('unit_id'),
                TextInput::make('deleted_by'),
            ]);
    }
}
