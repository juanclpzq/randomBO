<?php

namespace App\Filament\Resources\PurchaseOrderItems\Schemas;

use Filament\Forms\Components\TextInput;
use Filament\Schemas\Schema;

class PurchaseOrderItemForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('purchase_order_id')
                    ->required(),
                TextInput::make('inventory_item_id')
                    ->required(),
                TextInput::make('quantity')
                    ->required()
                    ->numeric(),
                TextInput::make('unit_id'),
                TextInput::make('cost')
                    ->numeric()
                    ->prefix('$'),
                TextInput::make('deleted_by'),
            ]);
    }
}
