<?php

namespace App\Filament\Resources\RecipeIngredients;

use App\Filament\Resources\RecipeIngredients\Pages\CreateRecipeIngredient;
use App\Filament\Resources\RecipeIngredients\Pages\EditRecipeIngredient;
use App\Filament\Resources\RecipeIngredients\Pages\ListRecipeIngredients;
use App\Filament\Resources\RecipeIngredients\Schemas\RecipeIngredientForm;
use App\Filament\Resources\RecipeIngredients\Tables\RecipeIngredientsTable;
use App\Models\RecipeIngredient;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\SoftDeletingScope;

class RecipeIngredientResource extends Resource
{
    protected static ?string $model = RecipeIngredient::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedRectangleStack;

    public static function shouldRegisterNavigation(): bool
    {
        return false;
    }

    public static function form(Schema $schema): Schema
    {
        return RecipeIngredientForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return RecipeIngredientsTable::configure($table);
    }

    public static function getRelations(): array
    {
        return [
            //
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListRecipeIngredients::route('/'),
            'create' => CreateRecipeIngredient::route('/create'),
            'edit' => EditRecipeIngredient::route('/{record}/edit'),
        ];
    }

    public static function getRecordRouteBindingEloquentQuery(): Builder
    {
        return parent::getRecordRouteBindingEloquentQuery()
            ->withoutGlobalScopes([
                SoftDeletingScope::class,
            ]);
    }
}
