<?php

namespace App\Filament\Resources\InventoryItems\Tables;

use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\ToggleColumn;
use Filament\Tables\Table;

class InventoryItemsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')->searchable()->sortable(),
                TextColumn::make('purchaseUnit.short_name')
                    ->label('Unidad de compra')
                    ->sortable()
                    ->searchable(),
                TextColumn::make('recipeUnit.short_name')
                    ->label('Unidad de receta')
                    ->sortable(),
                TextColumn::make('qty_per_purchase_unit')->label('Cantidad por unidad')->sortable(),
                TextColumn::make('minimum_limit')->label('Mínimo')->sortable(),
                ToggleColumn::make('status')->label('Activo'),
            ])
            ->headerActions([
                \Filament\Actions\CreateAction::make(),
            ])
            ->actions([
                \Filament\Actions\EditAction::make(),
                //\Filament\Actions\DeleteAction::make(),
                \Filament\Actions\ForceDeleteAction::make(),
                \Filament\Actions\RestoreAction::make(),
            ]);
    }
}
