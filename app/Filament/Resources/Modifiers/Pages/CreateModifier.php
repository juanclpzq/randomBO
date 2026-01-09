<?php

namespace App\Filament\Resources\Modifiers\Pages;

use App\Filament\Resources\Modifiers\ModifierResource;
use Filament\Resources\Pages\CreateRecord;

class CreateModifier extends CreateRecord
{
    protected static string $resource = ModifierResource::class;
}
