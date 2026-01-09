<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InventoryItemCost extends Model
{
    protected $table = 'inventory_item_costs';
    public $incrementing = false;
    public $timestamps = false;
    protected $primaryKey = ['location_id', 'inventory_item_id'];
    protected $keyType = 'string';
    protected $fillable = [
        'location_id', 'inventory_item_id', 'avg_unit_cost', 'last_unit_cost', 'updated_at'
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
