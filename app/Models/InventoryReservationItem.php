<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InventoryReservationItem extends Model
{
    protected $table = 'inventory_reservation_items';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $fillable = [
        'id', 'reservation_id', 'inventory_item_id', 'quantity', 'unit_id', 'created_at'
    ];

    public function reservation()
    {
        return $this->belongsTo(InventoryReservation::class, 'reservation_id');
    }
    public function inventoryItem()
    {
        return $this->belongsTo(InventoryItem::class);
    }
    public function unit()
    {
        return $this->belongsTo(Unit::class);
    }
}
