<?php

namespace App\Filament\Resources\RecipeIngredients\Pages;

use App\Filament\Resources\RecipeIngredients\RecipeIngredientResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListRecipeIngredients extends ListRecords
{
    protected static string $resource = RecipeIngredientResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make(),
        ];
    }
}
