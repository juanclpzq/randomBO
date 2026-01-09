<?php

namespace App\Filament\Resources\Items\Pages;

use App\Filament\Resources\Items\ItemResource;
use Filament\Actions\DeleteAction;
use Filament\Actions\ForceDeleteAction;
use Filament\Actions\RestoreAction;
use Filament\Resources\Pages\EditRecord;


class EditItem extends EditRecord
{
    protected static string $resource = ItemResource::class;

    public function mount($record): void
    {
        parent::mount($record);
        // Precarga todos los valores del registro y relaciones many-to-many
        $this->form->fill(array_merge(
            $this->record->attributesToArray(),
            [
                'modifierGroups' => $this->record->modifierGroups()->pluck('modifier_groups.id')->toArray(),
                'modifiers' => $this->record->modifiers()->pluck('modifiers.id')->toArray(),
                'exceptions' => $this->record->exceptions()->pluck('exceptions.id')->toArray(),
                'extras' => $this->record->extras()->pluck('extras.id')->toArray(),
            ]
        ));
    }

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make(),
            ForceDeleteAction::make(),
            RestoreAction::make(),
        ];
    }

    protected function mutateFormDataBeforeSave(array $data): array
    {
        // Extrae y remueve los arrays de relaciones para sincronizar después
        $this->modifierGroupsToSync = $data['modifierGroups'] ?? [];
        unset($data['modifierGroups']);
        $this->modifiersToSync = $data['modifiers'] ?? [];
        unset($data['modifiers']);
        $this->exceptionsToSync = $data['exceptions'] ?? [];
        unset($data['exceptions']);
        $this->extrasToSync = $data['extras'] ?? [];
        unset($data['extras']);
        return parent::mutateFormDataBeforeSave($data);
    }

    protected function handleRecordUpdate(
        \Illuminate\Database\Eloquent\Model $record,
        array $data
    ): \Illuminate\Database\Eloquent\Model {
        $updated = parent::handleRecordUpdate($record, $data);

        // Soft-delete logic for many-to-many pivots
        $this->syncWithSoftDelete($record, 'modifierGroups', 'items_modifier_groups', 'modifier_group_id', $this->modifierGroupsToSync ?? []);
        $this->syncWithSoftDelete($record, 'modifiers', 'items_modifiers', 'modifier_id', $this->modifiersToSync ?? []);
        $this->syncWithSoftDelete($record, 'exceptions', 'items_exceptions', 'exception_id', $this->exceptionsToSync ?? []);
        $this->syncWithSoftDelete($record, 'extras', 'items_extras', 'extra_id', $this->extrasToSync ?? []);

        return $updated;
    }

    /**
     * Sync many-to-many with soft-delete on pivot.
     */
    protected function syncWithSoftDelete($record, $relation, $pivotTable, $relatedKey, $newIds)
    {
        $itemKey = 'item_id';
        $now = now();
        $currentIds = $record->$relation()->wherePivotNull('deleted_at')->pluck($pivotTable.'.'.$relatedKey)->toArray();

        // Soft-delete removed
        $idsToDelete = array_diff($currentIds, $newIds);
        if (!empty($idsToDelete)) {
            \DB::table($pivotTable)
                ->where($itemKey, $record->id)
                ->whereIn($relatedKey, $idsToDelete)
                ->whereNull('deleted_at')
                ->update(['deleted_at' => $now]);
        }

        // Restore (un-delete) or attach new
        foreach ($newIds as $id) {
            $exists = \DB::table($pivotTable)
                ->where($itemKey, $record->id)
                ->where($relatedKey, $id)
                ->first();
            if ($exists) {
                if ($exists->deleted_at) {
                    \DB::table($pivotTable)
                        ->where($itemKey, $record->id)
                        ->where($relatedKey, $id)
                        ->update(['deleted_at' => null]);
                }
            } else {
                \DB::table($pivotTable)
                    ->insert([
                        $itemKey => $record->id,
                        $relatedKey => $id,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
            }
        }
    }
}
