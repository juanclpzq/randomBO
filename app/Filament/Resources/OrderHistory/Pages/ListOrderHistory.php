<?php

namespace App\Filament\Resources\OrderHistory\Pages;

use App\Filament\Resources\OrderHistory\OrderHistoryResource;
use Filament\Resources\Pages\ListRecords;

class ListOrderHistory extends ListRecords
{
    protected static string $resource = OrderHistoryResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }
}
