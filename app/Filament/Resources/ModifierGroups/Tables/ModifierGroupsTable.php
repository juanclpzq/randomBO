<?php

namespace App\Filament\Resources\ModifierGroups\Tables;

use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Actions\ForceDeleteBulkAction;
use Filament\Actions\RestoreBulkAction;
use Filament\Tables\Filters\TrashedFilter;
use Filament\Tables\Table;

class ModifierGroupsTable
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
                \Filament\Tables\Columns\IconColumn::make('multiple_select')
                    ->label('Múltiple')
                    ->boolean(),
                \Filament\Tables\Columns\IconColumn::make('required')
                    ->label('Requerido')
                    ->boolean(),
                \Filament\Tables\Columns\TextColumn::make('sort_order')
                    ->label('Orden')
                    ->sortable(),
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
