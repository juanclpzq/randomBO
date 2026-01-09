<?php

namespace App\Filament\Resources\PurchaseOrders\Schemas;

use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Select;
use Filament\Schemas\Schema;

use App\Models\InventoryItem;
use App\Models\Unit;

class PurchaseOrderForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->schema([
                Select::make('location_id')
                    ->nullable()
                    ->relationship('location', 'name'),
                Select::make('supplier_id')
                    ->nullable()
                    ->relationship('supplier', 'name'),
                Select::make('status')
                    ->default('pending'),
                \Filament\Forms\Components\Repeater::make('PurchaseOrderItems')
                    ->label('Items')
                    ->schema([
                        \Filament\Forms\Components\Select::make('inventory_item_id')
                            ->label('Item')
                            ->options(fn () => InventoryItem::pluck('name', 'id'))
                            ->searchable()
                            ->required(),
                        \Filament\Forms\Components\TextInput::make('quantity')
                            ->numeric()
                            ->required(),
                        \Filament\Forms\Components\Select::make('unit_id')
                            ->label('Unidad')
                            ->options(fn () => Unit::pluck('name', 'id'))
                            ->required(),
                        \Filament\Forms\Components\TextInput::make('cost')
                            ->numeric(),
                    ])
                    ->createItemButtonLabel('Agregar ítem')
                    ->columns(4)
                    ->columnSpanFull()
                    ->relationship()
                    ->reorderable()
                    ->cloneable()
                    ->collapsible(),
            ]);
    }
}
