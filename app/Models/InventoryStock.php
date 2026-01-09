<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InventoryStock extends Model
{
    protected $table = 'inventory_stocks';
    public $incrementing = false;
    public $timestamps = false;
    protected $primaryKey = ['location_id', 'inventory_item_id'];
    protected $keyType = 'string';
    protected $fillable = [
        'location_id', 'inventory_item_id', 'on_hand', 'reserved', 'updated_at'
    ];

    public function location()
    {
        return $this->belongsTo(Location::class);
    }
    public function inventoryItem()
    {
        return $this->belongsTo(InventoryItem::class);
    }
}
