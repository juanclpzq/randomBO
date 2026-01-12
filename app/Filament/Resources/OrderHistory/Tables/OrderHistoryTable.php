<?php

namespace App\Filament\Resources\OrderHistory\Tables;

use App\Models\Location;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\ViewAction;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class OrderHistoryTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                \Filament\Tables\Columns\TextColumn::make('order.order_number')
                    ->label('Order #')
                    ->sortable(),
                \Filament\Tables\Columns\TextColumn::make('event_type')
                    ->label('Event')
                    ->sortable(),
                \Filament\Tables\Columns\TextColumn::make('from_status')
                    ->label('From'),
                \Filament\Tables\Columns\TextColumn::make('to_status')
                    ->label('To'),
                \Filament\Tables\Columns\TextColumn::make('actor')
                    ->label('Actor'),
                \Filament\Tables\Columns\TextColumn::make('created_at')
                    ->label('When')
                    ->dateTime('d/m/Y H:i')
                    ->sortable(),
            ])
            ->filters([
                SelectFilter::make('location_id')
                    ->label('Location')
                    ->options(function () {
                        return Location::orderBy('name')->pluck('name', 'id')->toArray();
                    })
                    ->query(function ($query, $value) {
                        return $query->where('location_id', $value);
                    }),
            ])
            ->toolbarActions([])
            ->recordActions([
                ViewAction::make()->label('View Order')->url(fn($record) => url('/order-history/'.$record->order_id)),
            ])
            ->bulkActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ]);
    }
}
