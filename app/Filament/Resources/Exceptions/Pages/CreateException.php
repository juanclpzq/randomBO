<?php

namespace App\Filament\Resources\Exceptions\Pages;

use App\Filament\Resources\Exceptions\ExceptionResource;
use Filament\Resources\Pages\CreateRecord;

class CreateException extends CreateRecord
{
    protected static string $resource = ExceptionResource::class;
}
