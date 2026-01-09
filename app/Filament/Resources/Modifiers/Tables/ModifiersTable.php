<?php

namespace App\Filament\Resources\Modifiers\Tables;

use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Actions\ForceDeleteBulkAction;
use Filament\Actions\RestoreBulkAction;
use Filament\Tables\Filters\TrashedFilter;
use Filament\Tables\Table;

class ModifiersTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                \Filament\Tables\Columns\TextColumn::make('name')
                    ->label('Nombre')
                    ->searchable()
                    ->sortable(),
                \Filament\Tables\Columns\TextColumn::make('description')
                    ->label('Descripción')
                    ->limit(30),
                \Filament\Tables\Columns\IconColumn::make('status')
                    ->label('Activo')
                    ->boolean(),
                \Filament\Tables\Columns\TextColumn::make('price_change')
                    ->label('Cambio de precio')
                    ->money('MXN', true),
                \Filament\Tables\Columns\TextColumn::make('sort_order')
                    ->label('Orden')
                    ->sortable(),
                \Filament\Tables\Columns\TextColumn::make('modifierGroup.name')
                    ->label('Grupo')
                    ->sortable()
                    ->searchable(),
                \Filament\Tables\Columns\TextColumn::make('created_at')
                    ->label('Creado')
                    ->dateTime('d/m/Y')
                    ->sortable(),
            ])
            ->filters([
                TrashedFilter::make(),
            ])
            ->recordActions([
                EditAction::make(),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                    ForceDeleteBulkAction::make(),
                    RestoreBulkAction::make(),
                ]),
            ]);
    }
}
