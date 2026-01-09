<?php

namespace App\Filament\Resources\PurchaseOrderItems;

use App\Filament\Resources\PurchaseOrderItems\Pages\CreatePurchaseOrderItem;
use App\Filament\Resources\PurchaseOrderItems\Pages\EditPurchaseOrderItem;
use App\Filament\Resources\PurchaseOrderItems\Pages\ListPurchaseOrderItems;
use App\Filament\Resources\PurchaseOrderItems\Schemas\PurchaseOrderItemForm;
use App\Filament\Resources\PurchaseOrderItems\Tables\PurchaseOrderItemsTable;
use App\Models\PurchaseOrderItem;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\SoftDeletingScope;

class PurchaseOrderItemResource extends Resource
{
    protected static ?string $model = PurchaseOrderItem::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedRectangleStack;

    public static function form(Schema $schema): Schema
    {
        return PurchaseOrderItemForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return PurchaseOrderItemsTable::configure($table);
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
            'index' => ListPurchaseOrderItems::route('/'),
            'create' => CreatePurchaseOrderItem::route('/create'),
            'edit' => EditPurchaseOrderItem::route('/{record}/edit'),
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
